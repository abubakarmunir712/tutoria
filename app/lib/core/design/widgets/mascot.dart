import 'package:flutter/material.dart';

import '../tokens.dart';

/// Tutoria's little robot tutor, drawn in code as a stand-in until the illustrator's artwork is
/// delivered (see docs/DESIGN_SYSTEM.md: replace the body of this widget with an Image.asset).
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MascotPainter()),
    );
  }
}

class _MascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    Offset p(double x, double y) => Offset(x * w, y * h);

    // ears
    final ear = Paint()..color = TColors.blue500;
    canvas.drawCircle(p(0.12, 0.62), w * 0.1, ear);
    canvas.drawCircle(p(0.88, 0.62), w * 0.1, ear);
    final earRing = Paint()
      ..color = TColors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025;
    canvas.drawCircle(p(0.12, 0.62), w * 0.065, earRing);
    canvas.drawCircle(p(0.88, 0.62), w * 0.065, earRing);

    // head
    final head = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.3, w * 0.72, h * 0.62),
      Radius.circular(w * 0.3),
    );
    canvas.drawRRect(
      head,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3F95FF), TColors.blue600],
        ).createShader(head.outerRect),
    );

    // face plate
    final face = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.42, w * 0.56, h * 0.4),
      Radius.circular(w * 0.2),
    );
    canvas.drawRRect(face, Paint()..color = Colors.white);

    // eyes with highlights
    final eye = Paint()..color = const Color(0xFF0B2A7A);
    canvas.drawCircle(p(0.38, 0.58), w * 0.07, eye);
    canvas.drawCircle(p(0.62, 0.58), w * 0.07, eye);
    final shine = Paint()..color = Colors.white;
    canvas.drawCircle(p(0.36, 0.555), w * 0.022, shine);
    canvas.drawCircle(p(0.60, 0.555), w * 0.022, shine);

    // cheeks and smile
    final cheek = Paint()..color = const Color(0x66FF8FA3);
    canvas.drawCircle(p(0.3, 0.7), w * 0.045, cheek);
    canvas.drawCircle(p(0.7, 0.7), w * 0.045, cheek);
    final smile = Paint()
      ..color = const Color(0xFF0B2A7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: p(0.5, 0.68), width: w * 0.2, height: h * 0.12),
      0.25,
      2.65,
      false,
      smile,
    );

    // graduation cap
    final capColor = Paint()..color = const Color(0xFF0B2A7A);
    final board = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.94, h * 0.2)
      ..lineTo(w * 0.5, h * 0.34)
      ..lineTo(w * 0.06, h * 0.2)
      ..close();
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.28, h * 0.25, w * 0.44, h * 0.12),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(base, capColor);
    canvas.drawPath(board, capColor);
    canvas.drawPath(
      board,
      Paint()
        ..color = const Color(0xFF1C47B5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012,
    );

    // tassel
    final tassel = Paint()
      ..color = TColors.yellow
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p(0.9, 0.2), p(0.9, 0.36), tassel);
    canvas.drawCircle(p(0.9, 0.38), w * 0.03, Paint()..color = TColors.yellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
