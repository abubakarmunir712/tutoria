import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/design/design.dart';
import '../../core/progress.dart';
import '../../core/quiz.dart';
import '../progress/reward_toast.dart';

/// A unit's written assignment: the task, what a good answer includes, a place to write it up
/// and a short reflection. Marked against the success criteria.
class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({
    super.key,
    required this.learnerId,
    required this.topicId,
  });

  final String learnerId;
  final String topicId;

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  final _response = TextEditingController();
  final _reflection = TextEditingController();
  AssignmentInfo? _info;
  AssignmentOutcome? _outcome;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _response.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _response.dispose();
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final info = await context.read<ApiClient>().getAssignment(
        learnerId: widget.learnerId,
        topicId: widget.topicId,
      );
      if (mounted) setState(() => _info = info);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not load the assignment. Check your connection.',
        );
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final outcome = await context.read<ApiClient>().submitAssignment(
        learnerId: widget.learnerId,
        topicId: widget.topicId,
        response: _response.text.trim(),
        reflection: _reflection.text.trim(),
      );
      if (!mounted) return;
      setState(() => _outcome = outcome);
      unawaited(context.read<ProgressStore>().refresh(widget.learnerId));
      if (outcome.award != null) showAward(context, outcome.award!);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not hand that in. Try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: const Text('Assignment')),
      body: SafeArea(
        child: info == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TText.body),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  TSpace.page,
                  TSpace.sm,
                  TSpace.page,
                  TSpace.xl,
                ),
                children: [
                  Text(
                    info.topicName,
                    style: TText.title.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: TSpace.md),
                  TCard(
                    color: TColors.blue50,
                    borderColor: Colors.transparent,
                    shadow: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your task', style: TText.smallBold),
                        const SizedBox(height: 4),
                        Text(
                          info.task,
                          style: TText.bodyBold.copyWith(color: TColors.ink),
                        ),
                        const SizedBox(height: TSpace.md),
                        Text('A good answer has', style: TText.smallBold),
                        for (final c in info.criteria)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: TColors.success,
                                ),
                                const SizedBox(width: TSpace.sm),
                                Expanded(child: Text(c, style: TText.body)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_outcome != null) ...[
                    const SizedBox(height: TSpace.lg),
                    _Feedback(
                      verdict: _outcome!.verdict,
                      feedback: _outcome!.feedback,
                    ),
                  ] else ...[
                    if (info.lastFeedback != null) ...[
                      const SizedBox(height: TSpace.lg),
                      _Feedback(
                        verdict: info.lastVerdict ?? Verdict.partial,
                        feedback: info.lastFeedback!,
                        title: 'Last time',
                      ),
                    ],
                    const SizedBox(height: TSpace.xl),
                    Text('Your work', style: TText.label),
                    const SizedBox(height: TSpace.sm),
                    TextField(
                      controller: _response,
                      enabled: !_sending,
                      minLines: 6,
                      maxLines: 12,
                      maxLength: 4000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Write your steps and answers here',
                      ),
                    ),
                    if (info.reflectionPrompt.isNotEmpty) ...[
                      const SizedBox(height: TSpace.lg),
                      Text(info.reflectionPrompt, style: TText.label),
                      const SizedBox(height: TSpace.sm),
                      TextField(
                        controller: _reflection,
                        enabled: !_sending,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'A few words are fine',
                          counterText: '',
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: TSpace.sm),
                      Text(
                        _error!,
                        style: TText.small.copyWith(color: TColors.danger),
                      ),
                    ],
                    const SizedBox(height: TSpace.lg),
                    TButton(
                      label: 'Hand it in',
                      loading: _sending,
                      onPressed: _response.text.trim().length < info.minChars
                          ? null
                          : _submit,
                    ),
                    if (_response.text.trim().length < info.minChars)
                      Padding(
                        padding: const EdgeInsets.only(top: TSpace.sm),
                        child: Text(
                          'Write at least ${info.minChars} characters so your work can be checked.',
                          textAlign: TextAlign.center,
                          style: TText.small,
                        ),
                      ),
                  ],
                  if (_outcome != null) ...[
                    const SizedBox(height: TSpace.lg),
                    TButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.verdict, required this.feedback, this.title});

  final Verdict verdict;
  final String feedback;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final (color, tint, label) = switch (verdict) {
      Verdict.correct => (TColors.success, TColors.scienceTint, 'Well done!'),
      Verdict.partial => (TColors.warning, TColors.socialTint, 'Good start'),
      Verdict.incorrect => (
        TColors.danger,
        TColors.dangerTint,
        'Have another go',
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
              Icon(Icons.rate_review_rounded, color: color),
              const SizedBox(width: TSpace.sm),
              Text(
                title == null ? label : '$title: $label',
                style: TText.subheading.copyWith(color: TColors.ink),
              ),
            ],
          ),
          const SizedBox(height: TSpace.sm),
          Text(feedback, style: TText.body),
        ],
      ),
    );
  }
}
