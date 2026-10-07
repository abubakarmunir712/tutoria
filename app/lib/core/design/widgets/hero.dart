import 'package:flutter/material.dart';

import '../tokens.dart';

/// The blue hero backdrop (splash, home header): the brand gradient with soft circles and the
/// yellow "sparks" from the mockups.
class HeroBackground extends StatelessWidget {
  const HeroBackground({super.key, required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: TColors.heroGradient),
        child: CustomPaint(painter: _HeroPainter(), child: child),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.08),
      size.width * 0.42,
      soft,
    );
    canvas.drawCircle(
      Offset(-size.width * 0.1, size.height * 0.62),
      size.width * 0.5,
      soft,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Clips a header's bottom edge into a gentle wave, as under "Hi Ama" in the mockups.
class WaveClipper extends CustomClipper<Path> {
  const WaveClipper({this.depth = 28});

  final double depth;

  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - depth);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height + depth * 0.4,
      size.width * 0.55,
      size.height - depth * 0.55,
    );
    path.quadraticBezierTo(
      size.width * 0.82,
      size.height - depth * 1.3,
      size.width,
      size.height - depth * 0.5,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveClipper oldClipper) =>
      oldClipper.depth != depth;
}

/// The step indicator on the sign-up flow: the current step is a wide pill.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 6),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= index ? TColors.blue600 : TColors.blue200,
              borderRadius: BorderRadius.circular(TRadius.pill),
            ),
          ),
      ],
    );
  }
}

/// The Tutoria logo: the T mark beside the wordmark, in white for blue backgrounds or brand
/// blue for light ones, with the tagline underneath when [tagline] is set.
class Wordmark extends StatelessWidget {
  const Wordmark({
    super.key,
    this.size = 44,
    this.onBlue = false,
    this.tagline = false,
  });

  final double size;
  final bool onBlue;
  final bool tagline;

  @override
  Widget build(BuildContext context) {
    final color = onBlue ? Colors.white : TColors.blue600;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo_mark.png', height: size * 1.05),
            SizedBox(width: size * 0.2),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  'Tutoria',
                  style: TextStyle(
                    fontFamily: TText.family,
                    fontSize: size,
                    fontWeight: FontWeight.w900,
                    fontVariations: const [FontVariation('wght', 900)],
                    color: color,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                Positioned(
                  right: -size * 0.16,
                  top: -size * 0.2,
                  child: Icon(
                    Icons.star_rounded,
                    color: TColors.gold,
                    size: size * 0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (tagline) ...[
          SizedBox(height: size * 0.12),
          Padding(
            padding: EdgeInsets.only(left: size * 1.25),
            child: Text(
              'Your child’s personal AI tutor',
              style: TText.small.copyWith(
                color: onBlue ? Colors.white : TColors.ink,
                fontSize: size * 0.27,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The soft blue and yellow arcs in the corners of the light onboarding screens.
class SoftBlobs extends StatelessWidget {
  const SoftBlobs({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BlobPainter(), child: child);
  }
}

class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 0.05, size.height + size.width * 0.12),
      size.width * 0.42,
      Paint()..color = TColors.blue100,
    );
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height + size.width * 0.2),
      size.width * 0.3,
      Paint()..color = TColors.yellowTint,
    );
    canvas.drawCircle(
      Offset(size.width * 1.02, size.height * 0.96),
      size.width * 0.28,
      Paint()..color = TColors.blue100.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
