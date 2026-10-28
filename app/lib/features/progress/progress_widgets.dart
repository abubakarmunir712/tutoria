import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/progress.dart';

const _flame = Color(0xFFFF9500);
const _flameTint = Color(0xFFFFF0D9);

IconData badgeIcon(String code) => switch (code) {
  'first_question' => Icons.flag_rounded,
  'questions_10' => Icons.lightbulb_rounded,
  'questions_50' => Icons.psychology_rounded,
  'questions_100' => Icons.emoji_events_rounded,
  'streak_3' => Icons.local_fire_department_rounded,
  'streak_7' => Icons.whatshot_rounded,
  'streak_30' => Icons.workspace_premium_rounded,
  'photo_homework' => Icons.photo_camera_rounded,
  'voice_question' => Icons.mic_rounded,
  'explorer' => Icons.explore_rounded,
  'level_5' => Icons.military_tech_rounded,
  _ => Icons.star_rounded,
};

String xpLabel(int xp) => '$xp XP';

String daysLabel(int n) => n == 1 ? '1 day' : '$n days';

/// Level, XP and how far to the next level: the learner's score at a glance.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.progress, this.onTap, this.name});

  final Progress progress;
  final VoidCallback? onTap;

  /// Set when a parent is looking: "Ama is on level 3".
  final String? name;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return TCard(
      onTap: onTap,
      borderColor: Colors.transparent,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [TColors.gold, TColors.warning],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LEVEL',
                  style: TText.caption.copyWith(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  '${p.level}',
                  style: TText.heading.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name == null ? 'Your XP' : '$name’s XP',
                        style: TText.smallBold,
                      ),
                    ),
                    Text(
                      xpLabel(p.xp),
                      style: TText.heading.copyWith(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: p.levelFraction,
                    minHeight: 10,
                    backgroundColor: TColors.blue100,
                    valueColor: const AlwaysStoppedAnimation(TColors.gold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.xpToNextLevel} XP to level ${p.level + 1}',
                  style: TText.caption.copyWith(color: TColors.muted),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: TSpace.sm),
            const Icon(Icons.chevron_right_rounded, color: TColors.ink),
          ],
        ],
      ),
    );
  }
}

/// The last seven days as bars: how much the learner did each day.
class WeekChart extends StatelessWidget {
  const WeekChart({super.key, required this.week});

  final List<WeekDay> week;

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final most = week.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < week.length; i++)
            Expanded(
              child: _Bar(
                day: week[i],
                label: _initials[week[i].weekday - 1],
                fraction: most == 0 ? 0 : week[i].count / most,
                today: i == week.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.label,
    required this.fraction,
    required this.today,
  });

  final WeekDay day;
  final String label;
  final double fraction;
  final bool today;

  @override
  Widget build(BuildContext context) {
    const maxBar = 84.0;
    final active = day.count > 0;
    return Semantics(
      label:
          '$label: ${day.count} ${day.count == 1 ? 'question' : 'questions'}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            active ? '${day.count}' : '',
            style: TText.caption.copyWith(
              color: TColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 22,
            height: active ? 8 + (maxBar - 8) * fraction : 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: active
                  ? (today ? TColors.blue600 : TColors.blue500)
                  : TColors.blue100,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TText.caption.copyWith(
              color: today ? TColors.ink : TColors.muted,
              fontWeight: today ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One badge: coloured when earned, greyed with its goal when not.
class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.badge});

  final BadgeInfo badge;

  @override
  Widget build(BuildContext context) {
    final earned = badge.earned;
    return Semantics(
      label:
          '${badge.name}, ${earned ? 'earned' : 'locked'}. ${badge.description}',
      child: TCard(
        color: earned ? TColors.yellowTint : TColors.blue50,
        borderColor: earned ? TColors.yellowDeep : TColors.line,
        shadow: false,
        padding: const EdgeInsets.fromLTRB(6, TSpace.md, 6, TSpace.md),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: earned ? TColors.gold : TColors.line,
              ),
              child: Icon(
                earned ? badgeIcon(badge.code) : Icons.lock_rounded,
                color: earned ? Colors.white : TColors.faint,
                size: 24,
              ),
            ),
            const SizedBox(height: TSpace.sm),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TText.caption.copyWith(
                color: earned ? TColors.ink : TColors.muted,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TText.caption.copyWith(
                color: TColors.muted,
                fontSize: 10,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badges three to a row.
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({super.key, required this.badges});

  final List<BadgeInfo> badges;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = TSpace.sm;
        final width = (box.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final b in badges)
              SizedBox(
                width: width,
                child: BadgeTile(badge: b),
              ),
          ],
        );
      },
    );
  }
}

/// A figure with a label and a round icon, used on the rewards and parent screens.
class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = TColors.blue600,
    this.tint = TColors.blue100,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final Color tint;

  /// The fire colours used for streaks.
  const MiniStat.streak({super.key, required this.label, required this.value})
    : icon = Icons.local_fire_department_rounded,
      accent = _flame,
      tint = _flameTint;

  @override
  Widget build(BuildContext context) {
    return TCard(
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(TSpace.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: TSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  style: TText.caption.copyWith(
                    color: TColors.muted,
                    height: 1.1,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TText.heading.copyWith(fontSize: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
