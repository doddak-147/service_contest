import 'package:flutter/material.dart';

/// Decorative vector art, not a market-price chart.
class RiskLensIllustration extends StatelessWidget {
  const RiskLensIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '가상의 손실 구간을 확대해 보는 렌즈 일러스트',
      image: true,
      child: const SizedBox(
        width: double.infinity,
        height: 108,
        child: CustomPaint(painter: _RiskLensPainter()),
      ),
    );
  }
}

class _RiskLensPainter extends CustomPainter {
  const _RiskLensPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..strokeWidth = 1;
    for (final y in [h * 0.24, h * 0.53, h * 0.82]) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final curve = Path()
      ..moveTo(w * 0.02, h * 0.32)
      ..cubicTo(w * 0.14, h * 0.13, w * 0.20, h * 0.40, w * 0.30, h * 0.31)
      ..cubicTo(w * 0.42, h * 0.24, w * 0.44, h * 0.73, w * 0.57, h * 0.78)
      ..cubicTo(w * 0.72, h * 0.82, w * 0.79, h * 0.43, w * 0.98, h * 0.45);
    canvas.drawPath(
      curve,
      Paint()
        ..color = const Color(0xFF9CE3E6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final radius = h * 0.35;
    final center = Offset(w * 0.57, h * 0.47);
    canvas.drawLine(
      center + Offset(radius * 0.70, radius * 0.70),
      center + Offset(radius * 1.34, radius * 1.34),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );

    final lens = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(
      lens,
      Paint()..color = const Color(0xFF0A4251).withValues(alpha: 0.86),
    );
    canvas.save();
    canvas.clipPath(lens);
    final highlightedDip = Path()
      ..moveTo(center.dx - radius * 0.95, center.dy - radius * 0.54)
      ..cubicTo(
        center.dx - radius * 0.22,
        center.dy - radius * 0.72,
        center.dx - radius * 0.24,
        center.dy + radius * 0.40,
        center.dx + radius * 0.31,
        center.dy + radius * 0.45,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.73,
        center.dy + radius * 0.48,
        center.dx + radius * 1.10,
        center.dy - radius * 0.08,
      );
    canvas.drawPath(
      highlightedDip,
      Paint()
        ..color = const Color(0xFFFFBEAD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.drawPath(
      lens,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawCircle(
      center + Offset(radius * 0.10, radius * 0.29),
      4,
      Paint()..color = const Color(0xFFFFBEAD),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
