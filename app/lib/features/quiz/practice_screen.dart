import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/design/design.dart';
import '../../core/models.dart';
import '../../core/progress.dart';
import '../../core/quiz.dart';
import '../auth/auth_state.dart';
import 'assignment_screen.dart';
import 'mastery_widgets.dart';
import 'quiz_screen.dart';

/// A subject's practice units for the learner's class: each opens a quiz, a quick check or an
/// assignment, and shows how well the learner knows it.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.learnerId,
    required this.subject,
  });

  final String learnerId;
  final Subject subject;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  PracticeList? _list;
  String? _error;

  Learner get _learner =>
      context.read<AuthState>().learnerById(widget.learnerId)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await context.read<ApiClient>().practiceUnits(
        learnerId: widget.learnerId,
        subject: widget.subject.name,
      );
      if (mounted) setState(() => _list = list);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.statusCode == 404
              ? 'No practice yet for this subject.'
              : e.message,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load practice. Check your connection.',
        );
      }
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    unawaited(context.read<ProgressStore>().refresh(widget.learnerId));
    unawaited(_load());
  }

  void _showUnit(PracticeUnit unit) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TColors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TRadius.xl)),
      ),
      builder: (sheet) => _UnitSheet(
        unit: unit,
        subject: widget.subject.name,
        onQuiz: () {
          Navigator.pop(sheet);
          _open(
            QuizScreen(
              learnerId: widget.learnerId,
              topicId: unit.id,
              grade: _learner.grade,
              subject: widget.subject.name,
            ),
          );
        },
        onCheck: () {
          Navigator.pop(sheet);
          _open(
            QuizScreen(
              learnerId: widget.learnerId,
              topicId: unit.id,
              grade: _learner.grade,
              subject: widget.subject.name,
              check: true,
            ),
          );
        },
        onAssignment: () {
          Navigator.pop(sheet);
          _open(
            AssignmentScreen(learnerId: widget.learnerId, topicId: unit.id),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(widget.subject.name);
    final list = _list;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TSpace.page,
              0,
              TSpace.page,
              TSpace.xl,
            ),
            children: [
              Row(
                children: [
                  IconBadge(icon: style.icon, color: style.accent, size: 52),
                  const SizedBox(width: TSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Practice',
                          style: TText.title.copyWith(fontSize: 24),
                        ),
                        Text(
                          '${widget.subject.name} · ${_learner.classLabel}',
                          style: TText.small,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TSpace.xl),
              if (_error != null)
                Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TText.body.copyWith(color: TColors.muted),
                    ),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                )
              else if (list == null)
                const Padding(
                  padding: EdgeInsets.all(TSpace.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                TCard(
                  color: style.tint,
                  borderColor: Colors.transparent,
                  shadow: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.summary.started == 0
                            ? 'Pick a topic to take your first quiz'
                            : '${list.summary.done} of ${list.summary.total} topics secure',
                        style: TText.subheading,
                      ),
                      const SizedBox(height: TSpace.md),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: list.summary.fraction,
                          minHeight: 10,
                          backgroundColor: Colors.white.withValues(alpha: 0.7),
                          color: style.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TSpace.xl),
                for (final unit in list.units) ...[
                  _UnitCard(
                    unit: unit,
                    accent: style.accent,
                    onTap: () => _showUnit(unit),
                  ),
                  const SizedBox(height: TSpace.md),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.accent,
    required this.onTap,
  });

  final PracticeUnit unit;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TCard(
      onTap: onTap,
      selected: unit.recommended,
      padding: const EdgeInsets.symmetric(
        horizontal: TSpace.lg,
        vertical: TSpace.md,
      ),
      child: Row(
        children: [
          NumberBadge(number: unit.order, color: accent),
          const SizedBox(width: TSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.name,
                  style: TText.bodyBold.copyWith(color: TColors.ink),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: TSpace.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MasteryChip(mastery: unit.mastery, compact: true),
                    if (unit.bestPercent != null)
                      Text('Best ${unit.bestPercent}%', style: TText.small),
                    if (unit.recommended)
                      Text(
                        'Up next',
                        style: TText.smallBold.copyWith(color: TColors.blue600),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: TColors.ink),
        ],
      ),
    );
  }
}

class _UnitSheet extends StatelessWidget {
  const _UnitSheet({
    required this.unit,
    required this.subject,
    required this.onQuiz,
    required this.onCheck,
    required this.onAssignment,
  });

  final PracticeUnit unit;
  final String subject;
  final VoidCallback onQuiz;
  final VoidCallback onCheck;
  final VoidCallback onAssignment;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(subject);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TSpace.page,
          0,
          TSpace.page,
          TSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(unit.name, style: TText.title.copyWith(fontSize: 22)),
            const SizedBox(height: TSpace.sm),
            MasteryChip(mastery: unit.mastery),
            const SizedBox(height: TSpace.lg),
            _Action(
              icon: Icons.quiz_rounded,
              color: style.accent,
              title: unit.attempts == 0
                  ? 'Take the quiz'
                  : 'Take the quiz again',
              subtitle: '5 questions, from easy to tricky',
              onTap: onQuiz,
            ),
            const SizedBox(height: TSpace.md),
            _Action(
              icon: Icons.bolt_rounded,
              color: TColors.warning,
              title: 'Quick check',
              subtitle: unit.checked
                  ? '3 questions · done before'
                  : '3 questions to see what you already know',
              onTap: onCheck,
            ),
            const SizedBox(height: TSpace.md),
            _Action(
              icon: Icons.edit_note_rounded,
              color: Mastery.mastered.color,
              title: 'Assignment',
              subtitle: switch (unit.assignment) {
                Verdict.correct => 'Handed in · well done',
                Verdict.partial => 'Handed in · you can improve it',
                _ => 'Write up your own work',
              },
              onTap: onAssignment,
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TCard(
    onTap: onTap,
    child: Row(
      children: [
        IconBadge(icon: icon, color: color, size: 44),
        const SizedBox(width: TSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TText.subheading),
              Text(subtitle, style: TText.small),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: TColors.ink),
      ],
    ),
  );
}
