import 'package:flutter/material.dart';

import '../tokens.dart';

/// A solid coloured circle with a white icon: the badge on subject and action tiles.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// A round avatar showing someone's initials on a colour chosen from their name, so a child
/// keeps the same colour everywhere.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  static const _palette = [
    (TColors.mathsAccent, TColors.mathsTint),
    (TColors.englishAccent, TColors.englishTint),
    (TColors.scienceAccent, TColors.scienceTint),
    (TColors.socialAccent, TColors.socialTint),
    (TColors.worldAccent, TColors.worldTint),
    (TColors.computingAccent, TColors.computingTint),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed
              .split(RegExp(r'\s+'))
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join();
    final (accent, tint) =
        _palette[trimmed.codeUnits.fold<int>(0, (a, b) => a + b) %
            _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0245B0),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: trimmed.isEmpty
          ? Icon(Icons.person_rounded, color: accent, size: size * 0.5)
          : Text(
              initials,
              style: TText.heading.copyWith(
                color: accent,
                fontSize: size * 0.38,
              ),
            ),
    );
  }
}

/// A small rounded label, e.g. a class ("Class 5") or a subject.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    this.background = TColors.blue100,
    this.foreground = TColors.blue600,
    this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;

  /// A pill for use on a blue header.
  const Pill.onBlue({super.key, required this.text, this.icon})
    : background = const Color(0x33FFFFFF),
      foreground = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(text, style: TText.smallBold.copyWith(color: foreground)),
        ],
      ),
    );
  }
}

/// A solid coloured circle with a number: marks a topic's place in the curriculum order.
class NumberBadge extends StatelessWidget {
  const NumberBadge({
    super.key,
    required this.number,
    required this.color,
    this.size = 44,
  });

  final int number;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '$number',
        style: TText.heading.copyWith(
          color: Colors.white,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// "Hi Ama 👋" without the emoji: a drawn smiley, so it looks the same on every phone.
class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(text, style: style)),
        SizedBox(width: (style.fontSize ?? 28) * 0.25),
        Icon(
          Icons.emoji_emotions_rounded,
          color: TColors.yellow,
          size: (style.fontSize ?? 28) * 0.95,
        ),
      ],
    );
  }
}
