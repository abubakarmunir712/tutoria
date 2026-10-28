import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/design.dart';
import '../../core/progress.dart';
import 'progress_widgets.dart';

/// Rewards: the learner's level and XP, the badges they have and the ones still to win.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key, required this.learnerId});

  final String learnerId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProgressStore>();
    final p = store.of(learnerId) ?? Progress(studentId: learnerId);
    final earned = p.earnedBadges.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: TColors.pageGradient),
        child: RefreshIndicator(
          onRefresh: () => store.refresh(learnerId),
          child: ListView(
            padding: const EdgeInsets.all(TSpace.page),
            children: [
              LevelCard(progress: p),
              const SizedBox(height: TSpace.md),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: MiniStat.streak(
                        label: 'Learning streak',
                        value: daysLabel(p.streak),
                      ),
                    ),
                    const SizedBox(width: TSpace.md),
                    Expanded(
                      child: MiniStat(
                        label: 'Best streak',
                        value: daysLabel(p.bestStreak),
                        icon: Icons.emoji_events_rounded,
                        accent: TColors.yellowDeep,
                        tint: TColors.yellowTint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TSpace.xl),
              Row(
                children: [
                  Expanded(child: Text('Badges', style: TText.heading)),
                  Pill(
                    text: '$earned of ${p.badges.length}',
                    icon: Icons.workspace_premium_rounded,
                    background: TColors.yellowTint,
                    foreground: TColors.ink,
                  ),
                ],
              ),
              const SizedBox(height: TSpace.md),
              if (p.badges.isEmpty)
                TCard(
                  child: Text(
                    'Ask your first question to start collecting badges.',
                    style: TText.body,
                  ),
                )
              else
                BadgeGrid(badges: p.badges),
              const SizedBox(height: TSpace.xl),
              Text('How to earn XP', style: TText.heading),
              const SizedBox(height: TSpace.md),
              const TCard(
                child: Column(
                  children: [
                    _XpRule(Icons.chat_bubble_rounded, 'Ask a question', '+10'),
                    _XpRule(Icons.mic_rounded, 'Ask out loud', '+10'),
                    _XpRule(
                      Icons.photo_camera_rounded,
                      'Snap your homework',
                      '+15',
                    ),
                    _XpRule(
                      Icons.wb_sunny_rounded,
                      'Your first lesson each day',
                      '+10',
                    ),
                    _XpRule(
                      Icons.local_fire_department_rounded,
                      '3, 7, 14 and 30 day streaks',
                      'Bonus',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _XpRule extends StatelessWidget {
  const _XpRule(this.icon, this.text, this.xp);

  final IconData icon;
  final String text;
  final String xp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: TColors.blue600, size: 22),
          const SizedBox(width: TSpace.md),
          Expanded(child: Text(text, style: TText.body)),
          Text(xp, style: TText.bodyBold.copyWith(color: TColors.blue600)),
        ],
      ),
    );
  }
}
