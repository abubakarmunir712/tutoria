import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// The blue greeting header with a wavy lower edge, shared by the home screens.
class WaveHeader extends StatelessWidget {
  const WaveHeader({super.key, required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const WaveClipper(depth: 26),
      child: HeroBackground(
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TSpace.page,
                TSpace.lg,
                TSpace.page,
                48,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A speech bubble with a small tail, for the mascot's encouragement.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TSpace.lg,
        vertical: TSpace.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(TRadius.lg),
        boxShadow: TShadows.card,
      ),
      child: Text(
        text,
        style: TText.bodyBold.copyWith(
          color: TColors.blue600,
          fontStyle: FontStyle.italic,
          height: 1.3,
        ),
      ),
    );
  }
}
