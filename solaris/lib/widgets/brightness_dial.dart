import 'dart:math';
import 'package:flutter/material.dart';

class BrightnessDialPainter extends CustomPainter {
  // 0.0 to 1.0

  BrightnessDialPainter({required this.brightness});
  final double brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    // Draw background ring
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.7,
      pi * 1.6,
      false,
      bgPaint,
    );

    // Draw progress ring
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.7,
      pi * 1.6 * brightness,
      false,
      progressPaint,
    );

    // Draw Glow at the end of progress
    final endAngle = pi * 0.7 + pi * 1.6 * brightness;
    final endPos = Offset(
      center.dx + radius * cos(endAngle),
      center.dy + radius * sin(endAngle),
    );

    final glowPaint = Paint()
      ..color = const Color(0xFFFDBA74).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(endPos, 10, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
