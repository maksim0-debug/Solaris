import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BrightnessSlider extends StatelessWidget {
  const BrightnessSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(LucideIcons.sun, size: 14, color: Colors.white30),
              Text(
                '${value.round()}%',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1,
                ),
              ),
              const Icon(LucideIcons.sun, size: 18, color: Color(0xFFFDBA74)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 12,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.white.withOpacity(0.05),
              thumbColor: const Color(0xFFFDBA74),
              overlayColor: const Color(0xFFFDBA74).withOpacity(0.1),
              thumbShape: const _PremiumThumbShape(),
              trackShape: const _PremiumTrackShape(),
            ),
            child: Slider(value: value, min: 0, max: 100, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

class _PremiumTrackShape extends RoundedRectSliderTrackShape {
  const _PremiumTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final canvas = context.canvas;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // Inactive track
    final inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor!;
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        trackRect.left,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
        topLeft: const Radius.circular(10),
        bottomLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
        bottomRight: const Radius.circular(10),
      ),
      inactivePaint,
    );

    // Active track with gradient
    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
      ).createShader(trackRect);

    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        trackRect.left,
        trackRect.top,
        thumbCenter.dx,
        trackRect.bottom,
        topLeft: const Radius.circular(10),
        bottomLeft: const Radius.circular(10),
        topRight: Radius.zero,
        bottomRight: Radius.zero,
      ),
      activePaint,
    );
  }
}

class _PremiumThumbShape extends SliderComponentShape {
  const _PremiumThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(24, 24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Draw glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFDBA74).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 12, glowPaint);

    // Draw outer white ring
    final outerRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10, outerRingPaint);

    // Draw inner orange circle
    final innerCirclePaint = Paint()
      ..color = const Color(0xFFFDBA74)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, innerCirclePaint);
  }
}
