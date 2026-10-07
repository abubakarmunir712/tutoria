import 'package:flutter/material.dart';

import '../tokens.dart';

/// A white, softly shadowed card. Tappable when [onTap] is given.
class TCard extends StatelessWidget {
  const TCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(TSpace.lg),
    this.color = TColors.white,
    this.borderColor = TColors.line,
    this.selected = false,
    this.shadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final bool selected;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TRadius.lg);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow ? TShadows.card : null,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? TColors.blue600 : borderColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A large tinted choice card with an illustration, a title, a line of help text and a chevron
/// (the "I'm a Parent / I'm a Student" cards).
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.leading,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color tint;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TRadius.lg);
    return Material(
      color: tint,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: radius),
        child: Padding(
          padding: const EdgeInsets.all(TSpace.lg),
          child: Row(
            children: [
              leading,
              const SizedBox(width: TSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TText.subheading),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TText.small),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: TColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
