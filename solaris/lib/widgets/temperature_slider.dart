import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/constants/temperature_constants.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers/expanded_gamma_provider.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/widgets/deep_link_target.dart';
import 'package:solaris/widgets/expanded_gamma_dialog.dart';

class TemperatureSlider extends ConsumerWidget {
  const TemperatureSlider({
    required this.value,
    required this.onChanged,
    this.deepLinkKey,
    this.deepLinkId,
    super.key,
  });

  /// Symmetric side slot width ensuring slider body stays precisely centered
  /// and aligned with BrightnessSlider, with room for status indicator.
  static const double kSideSlotWidth = 36.0;

  /// Optional deep link global key and ID to target the inner 320px slider track directly,
  /// preserving symmetric 320px highlight glow without leaking onto side slots.
  final Key? deepLinkKey;
  final String? deepLinkId;

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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final double minTemp = TemperatureConstants.minDouble;
    final double maxTemp = TemperatureConstants.maxDouble;

    final clampedValue = value.clamp(minTemp, maxTemp);
    final double progress = valueToProgress(value: clampedValue);
    final Color currentColor = progressToColor(progress);

    final gammaStatusAsync = ref.watch(expandedGammaProvider);
    final ExpandedGammaStatus gammaStatus =
        gammaStatusAsync.value ?? ExpandedGammaStatus.disabled;
    final bool isWarmthZone =
        clampedValue < TemperatureConstants.expandedWarmthThresholdDouble;
    final bool showStatus =
        l10n != null &&
        gammaStatusAsync.hasValue &&
        (gammaStatus == ExpandedGammaStatus.disabled ||
            gammaStatus == ExpandedGammaStatus.pendingRestart);

    final Widget sliderBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    LucideIcons.snowflake,
                    size: 14,
                    color: Color(0xFF60A5FA),
                  ),
                ),
                Center(
                  child: Text(
                    '${value.round()}K',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: currentColor,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    LucideIcons.flame,
                    size: 18,
                    color: Color.lerp(
                      const Color(0xFFFDBA74),
                      const Color(0xFFEA580C),
                      ((progress - 0.58) / 0.42).clamp(0.0, 1.0),
                    ),
                  ),
                ),
              ],
            ),
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

    final Widget effectiveBody = deepLinkId != null
        ? DeepLinkTarget(key: deepLinkKey, id: deepLinkId!, child: sliderBody)
        : sliderBody;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: kSideSlotWidth),
        Expanded(child: effectiveBody),
        SizedBox(
          width: kSideSlotWidth,
          height: 48,
          child: Center(
            child: RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: showStatus
                    ? _ExpandedGammaPulseIndicator(
                        key: ValueKey('gamma_status_${gammaStatus.name}'),
                        gammaStatus: gammaStatus,
                        isWarmthZone: isWarmthZone,
                        tooltipMessage:
                            gammaStatus == ExpandedGammaStatus.disabled
                            ? l10n.expandedGammaWarningTooltip
                            : l10n.expandedGammaRestartPendingTooltip,
                        onTap: () {
                          debugPrint(
                            '🖱️ [TemperatureSlider] Status icon tapped ($gammaStatus), opening dialog...',
                          );
                          showExpandedGammaDialog(
                            context,
                            isPendingRestart:
                                gammaStatus ==
                                ExpandedGammaStatus.pendingRestart,
                          );
                        },
                      )
                    : const SizedBox.shrink(key: ValueKey('gamma_status_none')),
              ),
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

class _ExpandedGammaPulseIndicator extends StatefulWidget {
  final ExpandedGammaStatus gammaStatus;
  final bool isWarmthZone;
  final String tooltipMessage;
  final VoidCallback onTap;

  const _ExpandedGammaPulseIndicator({
    super.key,
    required this.gammaStatus,
    required this.isWarmthZone,
    required this.tooltipMessage,
    required this.onTap,
  });

  @override
  State<_ExpandedGammaPulseIndicator> createState() =>
      _ExpandedGammaPulseIndicatorState();
}

class _ExpandedGammaPulseIndicatorState
    extends State<_ExpandedGammaPulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _opacityAnimation;
  bool _isHovered = false;

  static bool get _isInTest => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _opacityAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_isInTest) {
      _pulseController.value = 1.0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  void _syncAnimationState() {
    if (!mounted) return;
    final bool disableAnimations =
        _isInTest || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (disableAnimations || _isHovered) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.value = 1.0;
    } else if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWarning = widget.gammaStatus == ExpandedGammaStatus.disabled;
    final Color accentColor = isWarning
        ? (widget.isWarmthZone
              ? const Color(0xFFFBBF24)
              : const Color(0xFFF59E0B))
        : const Color(0xFF10B981);
    final IconData iconData = isWarning
        ? LucideIcons.triangleAlert
        : LucideIcons.rotateCcw;

    return Tooltip(
      message: widget.tooltipMessage,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (hovered) {
            if (!mounted) return;
            if (_isHovered != hovered) {
              setState(() => _isHovered = hovered);
              _syncAnimationState();
            }
          },
          borderRadius: BorderRadius.circular(8),
          hoverColor: accentColor.withValues(alpha: 0.15),
          splashColor: accentColor.withValues(alpha: 0.25),
          child: SizedBox(
            width: TemperatureSlider.kSideSlotWidth,
            height: 40,
            child: Center(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _opacityAnimation,
                  builder: (context, child) {
                    final double currentOpacity = _isHovered
                        ? 1.0
                        : _opacityAnimation.value;
                    return Opacity(opacity: currentOpacity, child: child);
                  },
                  child: Icon(iconData, size: 20, color: accentColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
