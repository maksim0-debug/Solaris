import 'dart:math';
import 'package:flutter/material.dart';

class SunPathPainter extends CustomPainter {
  // 0.0 to 1.0 (Sunrise to Sunset)

  SunPathPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Relative Geometry - Ensures sun stays above the 240x240 brightness dial
    final dialRadius = 120.0;
    final arcHeadroom = 40.0; // Distance above the dial's top edge

    // We anchor the arc's curvature to the widget's center
    final centerOffset = size.height * 0.45;
    final center = Offset(size.width / 2, size.height / 2 + centerOffset);
    final radius = centerOffset + dialRadius + arcHeadroom;

    final arcPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Arc spanning from bottom-left to bottom-right through zenith
    const startAngle = pi * 1.1;
    const totalAngle = pi * 0.8;

    // Draw main subtle background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalAngle,
      false,
      arcPaint,
    );

    // Draw dashed path (stars/time slots)
    const dashCount = 60;
    for (var i = 0; i < dashCount; i++) {
      final angle = startAngle + (totalAngle * i / dashCount);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        (totalAngle / dashCount) * 0.4,
        false,
        dashPaint,
      );
    }

    // Progress mapping logic
    bool isNight = progress < 0 || progress > 1;
    double bodyProgress;
    if (isNight) {
      bodyProgress = progress > 1 ? progress - 1.0 : progress + 1.0;
    } else {
      bodyProgress = progress;
    }

    final bodyAngle = startAngle + (totalAngle * bodyProgress);
    final bodyPos = Offset(
      center.dx + radius * cos(bodyAngle),
      center.dy + radius * sin(bodyAngle),
    );

    if (!isNight) {
      _drawSun(canvas, bodyPos, bodyProgress);
    } else {
      _drawMoon(canvas, bodyPos);
    }
  }

  void _drawSun(Canvas canvas, Offset pos, double progress) {
    // Dynamic glow intensity and radius based on solar elevation (zenith = 0.5)
    final elevation = 1.0 - (progress - 0.5).abs() * 2.0;
    final glowRadius = 35.0 + (elevation * 25.0);
    final glowOpacity = (0.3 + (elevation * 0.5)).clamp(0.0, 0.8);

    final sunColor = const Color(0xFFFDBA74);

    // Multi-layered soft glow
    final outerGlow = Paint()
      ..color = sunColor.withOpacity(glowOpacity * 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 1.0);

    final innerGlow = Paint()
      ..color = sunColor.withOpacity(glowOpacity * 0.7)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.4);

    canvas.drawCircle(pos, glowRadius, outerGlow);
    canvas.drawCircle(pos, glowRadius * 0.6, innerGlow);

    // Main Sun Body
    final sunBody = Paint()
      ..color = sunColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pos, 22, sunBody);

    // Minimalist Sun Icon
    final iconPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final iconFill = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Inner core
    canvas.drawCircle(pos, 5, iconFill);

    // 8 rays
    const rayCount = 8;
    const rayInner = 9.0;
    const rayOuter = 13.0;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 2 * pi / rayCount);
      final p1 = Offset(
        pos.dx + rayInner * cos(angle),
        pos.dy + rayInner * sin(angle),
      );
      final p2 = Offset(
        pos.dx + rayOuter * cos(angle),
        pos.dy + rayOuter * sin(angle),
      );
      canvas.drawLine(p1, p2, iconPaint);
    }
  }

  void _drawMoon(Canvas canvas, Offset pos) {
    // Moon Glow
    final moonGlow = Paint()
      ..color = Colors.blueAccent.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

    canvas.drawCircle(pos, 45, moonGlow);

    final moonBody = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    // Crescent Path
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: pos, radius: 18)),
        Path()
          ..addOval(Rect.fromCircle(center: pos.translate(10, -5), radius: 18)),
      ),
      moonBody,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
