import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/progress.dart';

/// A short celebration under the app bar after an answer: the XP earned, a new level, a longer
/// streak or a new badge. Says nothing when the question earned nothing.
void showAward(BuildContext context, Award award) {
  if (!award.isNews) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: TColors.ink,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(TSpace.page, 0, TSpace.page, 96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TRadius.lg),
        ),
        content: AwardBanner(award: award),
      ),
    );
}

/// The content of the reward toast.
class AwardBanner extends StatelessWidget {
  const AwardBanner({super.key, required this.award});

  final Award award;

  @override
  Widget build(BuildContext context) {
    final extras = <String>[
      if (award.leveledUp) 'Level ${award.level} reached!',
      if (award.streakBonus > 0)
        '${award.streak}-day streak bonus +${award.streakBonus} XP',
      if (award.firstOfDay > 0) 'First lesson today +${award.firstOfDay} XP',
      for (final b in award.newBadges) 'New badge: ${b.name}',
    ];
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: TColors.gold, size: 34),
        const SizedBox(width: TSpace.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                award.xpGained > 0 ? '+${award.xpGained} XP' : 'Well done!',
                style: TText.subheading.copyWith(color: Colors.white),
              ),
              for (final line in extras)
                Text(
                  line,
                  style: TText.small.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
