import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/design/design.dart';
import '../../core/progress.dart';
import '../../core/quiz.dart';
import '../chat/chat_screen.dart';
import '../progress/reward_toast.dart';
import 'mastery_widgets.dart';

/// A quiz or quick check on one practice unit: one question at a time, a nudge and a second
/// try after a wrong answer, then the answer, and finally the result.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.learnerId,
    required this.topicId,
    required this.subject,
    this.grade,
    this.check = false,
  });

  final String learnerId;
  final String topicId;
  final String subject;
  final String? grade;

  /// The short diagnostic instead of the full quiz.
  final bool check;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

/// Where the current question is.
enum _Step {
  /// Waiting for an answer (first or second try).
  answering,

  /// The first try was not right: showing a nudge before the second.
  nudged,

  /// The question is done: showing how it went.
  settled,
}

class _QuizScreenState extends State<QuizScreen> {
  final _answer = TextEditingController();
  QuizAttempt? _attempt;
  String? _loadError;
  int _index = 0;
  _Step _step = _Step.answering;
  AnswerOutcome? _outcome;
  QuizResult? _result;
  bool _sending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _answer.addListener(() => setState(() {}));
    _start();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _loadError = null);
    try {
      final attempt = await context.read<ApiClient>().startQuiz(
        learnerId: widget.learnerId,
        topicId: widget.topicId,
        check: widget.check,
      );
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _index = attempt.firstOpen;
        // Picked up a question that already had a wrong first try.
        final q = _index < attempt.questions.length
            ? attempt.questions[_index]
            : null;
        if (q != null && q.tries > 0 && !q.settled) {
          _step = _Step.nudged;
          _outcome = AnswerOutcome(
            settled: false,
            verdict: q.verdict ?? Verdict.incorrect,
            feedback: q.feedback ?? '',
            triesLeft: 1,
          );
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Could not start. Check your connection.');
      }
    }
  }

  QuizQuestion get _question => _attempt!.questions[_index];

  Future<void> _send() async {
    final text = _answer.text.trim();
    if (text.isEmpty || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final outcome = await context.read<ApiClient>().answerQuestion(
        attemptId: _attempt!.attemptId,
        questionId: _question.id,
        answer: text,
      );
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _step = outcome.settled ? _Step.settled : _Step.nudged;
        if (outcome.result != null) _result = outcome.result;
      });
      if (outcome.result?.award != null) _afterFinish(outcome.result!);
    } on ApiException catch (e) {
      if (mounted) setState(() => _sendError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _sendError = 'Could not send that. Try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _afterFinish(QuizResult result) {
    unawaited(context.read<ProgressStore>().refresh(widget.learnerId));
    // Shown a moment later so it lands on the result screen, not the question.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted && result.award != null) showAward(context, result.award!);
    });
  }

  void _next() {
    if (_outcome?.done ?? false) {
      setState(
        () => _step = _Step.answering,
      ); // the result takes over the screen
      return;
    }
    setState(() {
      _index++;
      _step = _Step.answering;
      _outcome = null;
      _sendError = null;
      _answer.clear();
    });
  }

  void _askTutor(QuizResult r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          grade: widget.grade,
          subject: widget.subject,
          initialQuestion: r.askTutor ?? 'Teach me about ${r.topicName}',
          learnerId: widget.learnerId,
          topic: r.topicName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    final title = widget.check ? 'Quick check' : 'Quiz';

    if (_loadError != null || attempt == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(TSpace.page),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: TText.body.copyWith(color: TColors.muted),
                      ),
                      TextButton(
                        onPressed: _start,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final result = _result ?? attempt.result;
    if (result != null &&
        (_step == _Step.answering || attempt.result != null)) {
      return _ResultView(
        result: result,
        onDone: () => Navigator.of(context).pop(),
        onAskTutor: () => _askTutor(result),
        onRetry: widget.check
            ? null
            : () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => QuizScreen(
                    learnerId: widget.learnerId,
                    topicId: widget.topicId,
                    subject: widget.subject,
                    grade: widget.grade,
                  ),
                ),
              ),
      );
    }

    final total = attempt.questions.length;
    final q = _question;
    final style = SubjectStyle.of(widget.subject);
    final outcome = _outcome;

    return Scaffold(
      appBar: AppBar(title: Text('$title · ${attempt.topicName}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            TSpace.page,
            TSpace.sm,
            TSpace.page,
            TSpace.xl,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value:
                          (_index + (_step == _Step.settled ? 1 : 0)) / total,
                      minHeight: 10,
                      backgroundColor: style.tint,
                      color: style.accent,
                    ),
                  ),
                ),
                const SizedBox(width: TSpace.md),
                Text('${_index + 1} / $total', style: TText.smallBold),
              ],
            ),
            const SizedBox(height: TSpace.xl),
            Pill(
              text: q.levelLabel,
              background: style.tint,
              foreground: style.accent,
            ),
            const SizedBox(height: TSpace.md),
            Text(q.text, style: TText.title.copyWith(fontSize: 22)),
            const SizedBox(height: TSpace.xl),
            TextField(
              controller: _answer,
              enabled: _step != _Step.settled && !_sending,
              minLines: 2,
              maxLines: 5,
              maxLength: 600,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Type your answer here',
                counterText: '',
              ),
              style: TText.body.copyWith(fontSize: 17, color: TColors.ink),
            ),
            if (_sendError != null) ...[
              const SizedBox(height: TSpace.sm),
              Text(
                _sendError!,
                style: TText.small.copyWith(color: TColors.danger),
              ),
            ],
            const SizedBox(height: TSpace.lg),
            if (outcome != null && _step != _Step.answering)
              _OutcomeCard(outcome: outcome, step: _step),
            const SizedBox(height: TSpace.lg),
            if (_step == _Step.settled)
              TButton(
                label: (outcome?.done ?? false)
                    ? 'See my results'
                    : 'Next question',
                icon: Icons.arrow_forward_rounded,
                iconAfter: true,
                onPressed: _next,
              )
            else
              TButton(
                label: _step == _Step.nudged ? 'Try again' : 'Check my answer',
                loading: _sending,
                onPressed: _answer.text.trim().isEmpty && !_sending
                    ? null
                    : _send,
              ),
          ],
        ),
      ),
    );
  }
}

/// How an answer went: a nudge after a wrong first try, or the verdict and answer once done.
class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.outcome, required this.step});

  final AnswerOutcome outcome;
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final (color, tint, icon, title) = switch ((step, outcome.verdict)) {
      (_Step.nudged, _) => (
        TColors.warning,
        TColors.socialTint,
        Icons.lightbulb_rounded,
        outcome.verdict == Verdict.partial
            ? 'Nearly there! Try once more'
            : 'Not quite. Have another go',
      ),
      (_, Verdict.correct) => (
        TColors.success,
        TColors.scienceTint,
        Icons.check_circle_rounded,
        'Correct!',
      ),
      (_, Verdict.partial) => (
        TColors.warning,
        TColors.socialTint,
        Icons.change_history_rounded,
        'Partly right',
      ),
      _ => (
        TColors.danger,
        TColors.dangerTint,
        Icons.info_rounded,
        'Not this time',
      ),
    };
    return TCard(
      color: tint,
      borderColor: Colors.transparent,
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: TSpace.sm),
              Expanded(
                child: Text(
                  title,
                  style: TText.subheading.copyWith(color: TColors.ink),
                ),
              ),
            ],
          ),
          if (outcome.feedback.isNotEmpty) ...[
            const SizedBox(height: TSpace.sm),
            Text(outcome.feedback, style: TText.body),
          ],
          if (outcome.correctAnswer != null) ...[
            const SizedBox(height: TSpace.md),
            Text('The answer', style: TText.smallBold),
            Text(
              outcome.correctAnswer!,
              style: TText.bodyBold.copyWith(color: TColors.ink),
            ),
          ],
          if (outcome.workedSolution != null) ...[
            const SizedBox(height: TSpace.md),
            Text('How to work it out', style: TText.smallBold),
            Text(outcome.workedSolution!, style: TText.body),
          ],
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.onDone,
    required this.onAskTutor,
    this.onRetry,
  });

  final QuizResult result;
  final VoidCallback onDone;
  final VoidCallback onAskTutor;
  final VoidCallback? onRetry;

  String get _headline {
    if (result.percent >= 90) return 'Brilliant work!';
    if (result.percent >= 70) return 'Great job!';
    if (result.percent >= 50) return 'Good effort!';
    return 'Keep practising!';
  }

  @override
  Widget build(BuildContext context) {
    final changed =
        result.masteryBefore != null && result.masteryBefore != result.mastery;
    final style = SubjectStyle.of(result.subject);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(result.isCheck ? 'Quick check done' : 'Quiz done'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            TSpace.page,
            TSpace.sm,
            TSpace.page,
            TSpace.xl,
          ),
          children: [
            TCard(
              color: style.tint,
              borderColor: Colors.transparent,
              shadow: false,
              child: Column(
                children: [
                  Text(_headline, style: TText.title.copyWith(fontSize: 24)),
                  const SizedBox(height: TSpace.lg),
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: result.percent / 100,
                            strokeWidth: 12,
                            backgroundColor: Colors.white,
                            color: style.accent,
                          ),
                        ),
                        Text(
                          '${result.percent}%',
                          style: TText.display.copyWith(fontSize: 34),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: TSpace.md),
                  Text(
                    '${result.correct} of ${result.total} right first or second time',
                    style: TText.body,
                  ),
                  const SizedBox(height: TSpace.md),
                  MasteryChip(mastery: result.mastery),
                  if (changed)
                    Padding(
                      padding: const EdgeInsets.only(top: TSpace.sm),
                      child: Text(
                        'Up from ${result.masteryBefore!.label}',
                        style: TText.small,
                      ),
                    ),
                ],
              ),
            ),
            if (result.weakLevels.isNotEmpty) ...[
              const SizedBox(height: TSpace.lg),
              Text('Worth another look', style: TText.heading),
              const SizedBox(height: TSpace.sm),
              Wrap(
                spacing: TSpace.sm,
                runSpacing: TSpace.sm,
                children: [
                  for (final l in result.weakLevels)
                    Pill(
                      text: l,
                      background: TColors.socialTint,
                      foreground: TColors.warning,
                    ),
                ],
              ),
            ],
            if (result.prerequisite != null) ...[
              const SizedBox(height: TSpace.md),
              Text(
                'This topic builds on ${result.prerequisite}. A quick revisit may help.',
                style: TText.body,
              ),
            ],
            const SizedBox(height: TSpace.xl),
            Text('Your answers', style: TText.heading),
            const SizedBox(height: TSpace.md),
            for (final r in result.review) ...[
              _ReviewTile(item: r),
              const SizedBox(height: TSpace.sm),
            ],
            const SizedBox(height: TSpace.lg),
            if (result.askTutor != null) ...[
              TButton(
                label: 'Ask Tutoria to explain',
                icon: Icons.chat_bubble_rounded,
                style: TButtonStyle.soft,
                onPressed: onAskTutor,
              ),
              const SizedBox(height: TSpace.md),
            ],
            if (onRetry != null && result.percent < 100) ...[
              TButton(
                label: 'Try the quiz again',
                icon: Icons.replay_rounded,
                style: TButtonStyle.outline,
                onPressed: onRetry,
              ),
              const SizedBox(height: TSpace.md),
            ],
            if (result.next != null)
              Padding(
                padding: const EdgeInsets.only(bottom: TSpace.md),
                child: Text(
                  'Up next: ${result.next!.name}',
                  textAlign: TextAlign.center,
                  style: TText.smallBold,
                ),
              ),
            TButton(label: 'Done', onPressed: onDone),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.item});

  final ReviewItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.verdict) {
      Verdict.correct => (Icons.check_circle_rounded, TColors.success),
      Verdict.partial => (Icons.change_history_rounded, TColors.warning),
      Verdict.incorrect => (Icons.cancel_rounded, TColors.danger),
    };
    return TCard(
      padding: const EdgeInsets.symmetric(
        horizontal: TSpace.lg,
        vertical: TSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: TSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.text,
                  style: TText.bodyBold.copyWith(color: TColors.ink),
                ),
                if (item.yourAnswer != null)
                  Text('You said: ${item.yourAnswer}', style: TText.small),
                if (item.correctAnswer != null)
                  Text(
                    'Answer: ${item.correctAnswer}',
                    style: TText.smallBold.copyWith(color: TColors.success),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
