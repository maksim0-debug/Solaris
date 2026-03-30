import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class TemperatureSlider extends StatelessWidget {
  const TemperatureSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final double value; // Real value: 2000.0 to 6500.0
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    // Map value so 6500 is Left (0.0) and 2000 is Right (1.0)
    final minTemp = 2000.0;
    final maxTemp = 6500.0;

    // clamp value just in case
    final clampedValue = value.clamp(minTemp, maxTemp);

    // progress: 0.0 (Cold/Left/6500K) to 1.0 (Warm/Right/2000K)
    final double progress = (maxTemp - clampedValue) / (maxTemp - minTemp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                LucideIcons.snowflake,
                size: 14,
                color: Color(0xFF60A5FA),
              ),
              Text(
                '${value.round()}K',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1,
                ),
              ),
              const Icon(LucideIcons.flame, size: 18, color: Color(0xFFFDBA74)),
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
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.1),
              thumbShape: _PremiumThumbShape(progress: progress),
              trackShape: const _PremiumTrackShape(),
            ),
            child: Slider(
              value: progress,
              min: 0.0,
              max: 1.0,
              onChanged: (val) {
                // val is 0.0 (Cold) to 1.0 (Warm)
                final realTemp = maxTemp - val * (maxTemp - minTemp);
                onChanged(realTemp);
              },
            ),
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

    // Active track with gradient from Blue to Orange
    final activePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF60A5FA), Color(0xFFFDBA74)],
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
  final double progress;
  const _PremiumThumbShape({required this.progress});

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

    // Interpolate color based on progress
    final Color currentColor = Color.lerp(
      const Color(0xFF60A5FA),
      const Color(0xFFFDBA74),
      progress,
    )!;

    // Draw glow
    final glowPaint = Paint()
      ..color = currentColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 12, glowPaint);

    // Draw outer white ring
    final outerRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10, outerRingPaint);

    // Draw inner circle
    final innerCirclePaint = Paint()
      ..color = currentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, innerCirclePaint);
  }
}
