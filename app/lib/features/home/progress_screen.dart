import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity.dart';
import '../../core/design/design.dart';
import 'student_home_screen.dart' show StatCard;

/// The Progress tab: how much the learner has asked, their streak and where they spend time.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.learnerId, this.now});

  final String learnerId;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityTracker>().of(learnerId);
    final clock = now ?? DateTime.now();
    final streak = activity.streakAt(clock);
    final subjects = activity.bySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final most = subjects.isEmpty ? 1 : subjects.first.value;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: TColors.pageGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(TSpace.page),
            children: [
              Text('Progress', style: TText.title.copyWith(fontSize: 28)),
              const SizedBox(height: 2),
              Text(
                'Small steps every day lead to big progress!',
                style: TText.body.copyWith(color: TColors.muted, fontSize: 16),
              ),
              const SizedBox(height: TSpace.xl),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Questions asked',
                        value: '${activity.questions}',
                        icon: Icons.track_changes_rounded,
                        accent: TColors.blue600,
                        tint: TColors.blue100,
                      ),
                    ),
                    const SizedBox(width: TSpace.md),
                    Expanded(
                      child: StatCard(
                        label: 'Learning streak',
                        value: streak == 1 ? '1 day' : '$streak days',
                        icon: Icons.local_fire_department_rounded,
                        accent: const Color(0xFFFF9500),
                        tint: const Color(0xFFFFF0D9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TSpace.xl),
              Text('Where you have been learning', style: TText.heading),
              const SizedBox(height: TSpace.md),
              if (subjects.isEmpty)
                TCard(
                  child: Text(
                    'Nothing here yet. Ask your first question and your progress will show up.',
                    style: TText.body,
                  ),
                )
              else
                for (final e in subjects) ...[
                  _SubjectBar(subject: e.key, count: e.value, most: most),
                  const SizedBox(height: TSpace.md),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({
    required this.subject,
    required this.count,
    required this.most,
  });

  final String subject;
  final int count;
  final int most;

  @override
  Widget build(BuildContext context) {
    final style = SubjectStyle.of(subject);
    return TCard(
      color: style.tint,
      borderColor: Colors.transparent,
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: style.icon, color: style.accent, size: 36),
              const SizedBox(width: TSpace.md),
              Expanded(child: Text(subject, style: TText.bodyBold)),
              Text(
                count == 1 ? '1 question' : '$count questions',
                style: TText.smallBold,
              ),
            ],
          ),
          const SizedBox(height: TSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: count / most,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.7),
              valueColor: AlwaysStoppedAnimation(style.accent),
            ),
          ),
        ],
      ),
    );
  }
}
