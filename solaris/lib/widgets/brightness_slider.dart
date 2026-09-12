import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BrightnessSlider extends StatelessWidget {
  const BrightnessSlider({
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 100.0,
    this.isSoftwareDimmingEnabled = false,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final bool isSoftwareDimmingEnabled;

  /// Piecewise mapping:
  /// When software dimming is enabled:
  /// - 25% of the slider width (0.0 .. 0.25) is dedicated to [-100.0 .. 0.0] overlay dimming.
  /// - 75% of the slider width (0.25 .. 1.0) is dedicated to [0.0 .. 100.0] hardware brightness.
  /// When disabled:
  /// - 100% of the slider width is linear [0.0 .. 100.0].
  static double valueToProgress({
    required double value,
    required bool isSoftwareDimmingEnabled,
  }) {
    if (!isSoftwareDimmingEnabled) {
      return (value / 100.0).clamp(0.0, 1.0);
    }
    if (value <= 0.0) {
      final ratio = (value - (-100.0)) / 100.0;
      return (ratio * 0.25).clamp(0.0, 0.25);
    } else {
      final ratio = value / 100.0;
      return (0.25 + ratio * 0.75).clamp(0.25, 1.0);
    }
  }

  static double progressToValue({
    required double progress,
    required bool isSoftwareDimmingEnabled,
  }) {
    if (!isSoftwareDimmingEnabled) {
      return (progress * 100.0).clamp(0.0, 100.0);
    }
    if (progress <= 0.25) {
      final ratio = progress / 0.25;
      return (-100.0 + ratio * 100.0).clamp(-100.0, 0.0);
    } else {
      final ratio = (progress - 0.25) / 0.75;
      return (ratio * 100.0).clamp(0.0, 100.0);
    }
  }

  void _handleChanged(double progress) {
    final rawVal = progressToValue(
      progress: progress,
      isSoftwareDimmingEnabled: isSoftwareDimmingEnabled,
    );

    // Magnetic Snap around 0% (threshold of ±3%) when software dimming is enabled
    if (isSoftwareDimmingEnabled && rawVal.abs() <= 3.0) {
      onChanged(0.0);
    } else {
      onChanged(rawVal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBelowZero = isSoftwareDimmingEnabled && value < 0.0;
    final double effectiveMin = isSoftwareDimmingEnabled ? min : 0.0;
    final double clampedVal = value.clamp(effectiveMin, max);
    final double progress = valueToProgress(
      value: clampedVal,
      isSoftwareDimmingEnabled: isSoftwareDimmingEnabled,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              isBelowZero
                  ? const Icon(
                      LucideIcons.moon,
                      size: 15,
                      color: Color(0xFF818CF8),
                    )
                  : Icon(
                      isSoftwareDimmingEnabled
                          ? LucideIcons.moon
                          : LucideIcons.sun,
                      size: 14,
                      color: Colors.white30,
                    ),
              isBelowZero
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF818CF8).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.moon,
                            size: 10,
                            color: Color(0xFF818CF8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${clampedVal.round()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC4B5FD),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      '${clampedVal.round()}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white54,
                        letterSpacing: 1,
                      ),
                    ),
              Icon(
                LucideIcons.sun,
                size: 18,
                color: isBelowZero ? Colors.white24 : const Color(0xFFFDBA74),
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
            border: Border.all(
              color: isBelowZero
                  ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 12,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
              thumbColor: isBelowZero
                  ? const Color(0xFF818CF8)
                  : const Color(0xFFFDBA74),
              overlayColor: isBelowZero
                  ? const Color(0xFF818CF8).withValues(alpha: 0.1)
                  : const Color(0xFFFDBA74).withValues(alpha: 0.1),
              thumbShape: _PremiumThumbShape(isBelowZero: isBelowZero),
              trackShape: _PremiumTrackShape(
                isSoftwareDimmingEnabled: isSoftwareDimmingEnabled,
              ),
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
  const _PremiumTrackShape({required this.isSoftwareDimmingEnabled});

  final bool isSoftwareDimmingEnabled;

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

    final trackRadius = Radius.circular(trackRect.height / 2);

    // Inactive track base
    final inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, trackRadius),
      inactivePaint,
    );

    if (isSoftwareDimmingEnabled) {
      // 25% of the slider width is dedicated to the overlay (-100%..0%)
      const zeroRatio = 0.25;
      final zeroDx = trackRect.left + trackRect.width * zeroRatio;

      // 1. Midnight Dock (Lunar Zone): Deep indigo background for the 0..25% zone
      final lunarDockRect = Rect.fromLTRB(
        trackRect.left,
        trackRect.top,
        zeroDx,
        trackRect.bottom,
      );
      final lunarDockPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF2E1065)],
        ).createShader(lunarDockRect);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          trackRect.left,
          trackRect.top,
          zeroDx,
          trackRect.bottom,
          topLeft: trackRadius,
          bottomLeft: trackRadius,
          topRight: Radius.zero,
          bottomRight: Radius.zero,
        ),
        lunarDockPaint,
      );

      if (thumbCenter.dx >= zeroDx) {
        // Positive zone (0% to +100%): Warm orange sun gradient
        final activePaint = Paint()
          ..shader =
              const LinearGradient(
                colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
              ).createShader(
                Rect.fromLTRB(
                  zeroDx,
                  trackRect.top,
                  trackRect.right,
                  trackRect.bottom,
                ),
              );

        canvas.drawRRect(
          RRect.fromLTRBAndCorners(
            zeroDx,
            trackRect.top,
            thumbCenter.dx,
            trackRect.bottom,
            topLeft: Radius.zero,
            bottomLeft: Radius.zero,
            topRight: trackRadius,
            bottomRight: trackRadius,
          ),
          activePaint,
        );
      } else {
        // Negative zone (-100% to 0%): Cool indigo moon gradient
        final activePaint = Paint()
          ..shader =
              const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
              ).createShader(
                Rect.fromLTRB(
                  trackRect.left,
                  trackRect.top,
                  zeroDx,
                  trackRect.bottom,
                ),
              );

        canvas.drawRRect(
          RRect.fromLTRBAndCorners(
            thumbCenter.dx,
            trackRect.top,
            zeroDx,
            trackRect.bottom,
            topLeft: trackRadius,
            bottomLeft: trackRadius,
            topRight: Radius.zero,
            bottomRight: Radius.zero,
          ),
          activePaint,
        );
      }

      // 2. Refined Seamless Chromatic Capsule Divider at 25% mark
      final capsuleRect = Rect.fromCenter(
        center: Offset(zeroDx, trackRect.center.dy),
        width: 3.0,
        height: 15.0,
      );

      // Chromatic ambient glow transitioning from lunar indigo to solar orange
      final glowPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF818CF8), Color(0xFFFDBA74)],
        ).createShader(capsuleRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(capsuleRect, const Radius.circular(1.5)),
        glowPaint,
      );

      // Chromatic gradient capsule core (Indigo -> Pure Luminous White -> Sun Orange)
      final capsulePaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF818CF8), // Moon / Overlay Indigo
            Color(0xFFFFFFFF), // Pure bright center highlight
            Color(0xFFFDBA74), // Sun / Physical Orange
          ],
          stops: [0.0, 0.45, 1.0],
        ).createShader(capsuleRect)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(capsuleRect, const Radius.circular(1.5)),
        capsulePaint,
      );
    } else {
      // Standard positive track gradient
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
          topLeft: trackRadius,
          bottomLeft: trackRadius,
          topRight: Radius.zero,
          bottomRight: Radius.zero,
        ),
        activePaint,
      );
    }
  }
}

class _PremiumThumbShape extends SliderComponentShape {
  const _PremiumThumbShape({this.isBelowZero = false});

  final bool isBelowZero;

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

    final Color glowColor = isBelowZero
        ? const Color(0xFF818CF8)
        : const Color(0xFFFDBA74);
    final Color innerColor = isBelowZero
        ? const Color(0xFF6366F1)
        : const Color(0xFFFDBA74);

    // Draw glow
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 12, glowPaint);

    // Draw outer white ring
    final outerRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10, outerRingPaint);

    // Draw inner circle
    final innerCirclePaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, innerCirclePaint);
  }
}
