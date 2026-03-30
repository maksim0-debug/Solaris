import 'dart:math';
import 'package:flutter/material.dart';

class TemperatureDialPainter extends CustomPainter {
  // progress from 0.0 to 1.0 (left to right)
  // mapped to - something similar to brightness
  TemperatureDialPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF60A5FA), Color(0xFFFDBA74)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Draw background ring (same arc space as brightness)
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
      pi * 1.6 * progress,
      false,
      progressPaint,
    );

    // Draw Glow at the end of progress
    final endAngle = pi * 0.7 + pi * 1.6 * progress;
    final endPos = Offset(
      center.dx + radius * cos(endAngle),
      center.dy + radius * sin(endAngle),
    );

    final Color currentColor = Color.lerp(
      const Color(0xFF60A5FA),
      const Color(0xFFFDBA74),
      progress,
    )!;

    final glowPaint = Paint()
      ..color = currentColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(endPos, 8, glowPaint);

    // Add small white pip as "white glow" on the end
    final pipPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(endPos, 3, pipPaint);
  }

  @override
  bool shouldRepaint(covariant TemperatureDialPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
