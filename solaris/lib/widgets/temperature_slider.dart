import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/constants/temperature_constants.dart';

class TemperatureSlider extends StatelessWidget {
  const TemperatureSlider({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Real value: 1000.0 to 6500.0
  final double value;
  final ValueChanged<double> onChanged;

  /// Pure linear mapping across the entire 1000K..6500K range:
  /// 0.0 = 6500K (Daylight Blue)
  /// 0.58 ≈ 3300K (Warm Amber)
  /// 1.0 = 1000K (Candlelight Ember)
  static double valueToProgress({required double value}) {
    final double maxTemp = TemperatureConstants.maxDouble;
    final double minTemp = TemperatureConstants.minDouble;
    final clamped = value.clamp(minTemp, maxTemp);
    return ((maxTemp - clamped) / (maxTemp - minTemp)).clamp(0.0, 1.0);
  }

  static double progressToValue({required double progress}) {
    final double maxTemp = TemperatureConstants.maxDouble;
    final double minTemp = TemperatureConstants.minDouble;
    final clampedP = progress.clamp(0.0, 1.0);
    return maxTemp - clampedP * (maxTemp - minTemp);
  }

  static Color progressToColor(double progress) {
    final clampedP = progress.clamp(0.0, 1.0);
    if (clampedP <= 0.58) {
      final ratio = (clampedP / 0.58).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFF60A5FA),
        const Color(0xFFFDBA74),
        ratio,
      )!;
    } else {
      final ratio = ((clampedP - 0.58) / 0.42).clamp(0.0, 1.0);
      return Color.lerp(
        const Color(0xFFFDBA74),
        const Color(0xFFEA580C),
        ratio,
      )!;
    }
  }

  static const LinearGradient trackGradient = LinearGradient(
    colors: [Color(0xFF60A5FA), Color(0xFFFDBA74), Color(0xFFEA580C)],
    stops: [0.0, 0.58, 1.0],
  );

  void _handleChanged(double progress) {
    final rawVal = progressToValue(progress: progress);
    onChanged(rawVal);
  }

  @override
  Widget build(BuildContext context) {
    final double minTemp = TemperatureConstants.minDouble;
    final double maxTemp = TemperatureConstants.maxDouble;

    final clampedValue = value.clamp(minTemp, maxTemp);
    final double progress = valueToProgress(value: clampedValue);
    final Color currentColor = progressToColor(progress);

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
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: currentColor,
                  letterSpacing: 1,
                ),
              ),
              Icon(
                LucideIcons.flame,
                size: 18,
                color: Color.lerp(
                  const Color(0xFFFDBA74),
                  const Color(0xFFEA580C),
                  ((progress - 0.58) / 0.42).clamp(0.0, 1.0),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 12,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.1),
              thumbShape: _PremiumThumbShape(progress: progress),
              trackShape: const _PremiumTrackShape(),
            ),
            child: Slider(
              value: progress,
              min: 0.0,
              max: 1.0,
              onChanged: _handleChanged,
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

    // Active track with pure linear gradient from Blue -> Amber -> Candlelight Ember
    final activePaint = Paint()
      ..shader = TemperatureSlider.trackGradient.createShader(trackRect);

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

    final Color currentColor = TemperatureSlider.progressToColor(progress);

    // Draw glow
    final glowPaint = Paint()
      ..color = currentColor.withValues(alpha: 0.3)
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
