import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/brightness_target.dart';
import 'package:solaris/utils/brightness_display_format.dart';
import 'package:solaris/widgets/weather_icon_helper.dart';
import 'package:solaris/widgets/phase_base_label.dart';

class CircadianBreakdownTooltip extends StatelessWidget {
  const CircadianBreakdownTooltip({
    super.key,
    required this.child,
    required this.target,
    this.appliedBrightness,
    this.monitorName,
    this.offset = 0,
    this.minimumBrightness = 0,
    this.isMonitorGroup = false,
    this.appliedValues = const [],
  });

  final Widget child;
  final BrightnessTarget target;
  final double? appliedBrightness;
  final String? monitorName;
  final double offset;
  final double minimumBrightness;
  final bool isMonitorGroup;
  final List<({String name, num value})> appliedValues;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final smartData = target.data;
    final withOffset = target.value + offset;
    final bounded = withOffset.clamp(minimumBrightness, 100.0);
    final rounded = bounded.round();
    final rounding = rounded - bounded;

    return Tooltip(
      richMessage: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.5,
          fontFamily: 'Outfit', // Consistent with AppTheme
        ),
        children: [
          if (monitorName != null)
            TextSpan(
              text:
                  '${isMonitorGroup ? monitorName! : l10n.brightnessMonitor(monitorName!)}\n',
            ),
          _buildRow(
            icon: LucideIcons.sun,
            label: _sourceLabel(l10n).toUpperCase(),
            value: '${formatBrightnessValue(smartData.baseBrightness)}%',
            iconColor: const Color(0xFFFDBA74),
          ),
          if (smartData.elevationShiftBrightnessImpact.abs() >= 0.005)
            _change(
              LucideIcons.sunrise,
              l10n.brightnessElevationShift,
              smartData.elevationShiftBrightnessImpact,
            ),
          if (smartData.weatherAbsoluteImpact.abs() >= 0.005)
            _change(
              getWeatherIcon(smartData.weatherCode),
              l10n.weatherBrightnessAdjustmentTitle,
              -smartData.weatherAbsoluteImpact,
            ),
          if (smartData.windDownAbsoluteImpact.abs() >= 0.005)
            _change(
              LucideIcons.moon,
              l10n.featureWindDownShort,
              -smartData.windDownAbsoluteImpact,
            ),
          if (smartData.sleepPressureAbsoluteImpact.abs() >= 0.005)
            _change(
              LucideIcons.hourglass,
              l10n.featureSleepPressureShort,
              -smartData.sleepPressureAbsoluteImpact,
            ),
          if (smartData.sleepDebtAbsoluteImpact.abs() >= 0.005)
            _change(
              LucideIcons.battery,
              l10n.featureSleepDebtShort,
              -smartData.sleepDebtAbsoluteImpact,
            ),
          if (smartData.timeShiftBrightnessImpact.abs() >= 0.005)
            _change(
              LucideIcons.sunrise,
              l10n.brightnessMorningBoost,
              smartData.timeShiftBrightnessImpact,
            ),
          if (smartData.brightnessLimitImpact.abs() >= 0.005)
            _change(
              LucideIcons.slidersHorizontal,
              l10n.calculationLimit,
              smartData.brightnessLimitImpact,
            ),
          if (offset.abs() >= 0.005)
            _change(LucideIcons.monitor, l10n.brightnessOffset, offset),
          if ((bounded - withOffset).abs() >= 0.005)
            _change(
              LucideIcons.slidersHorizontal,
              l10n.monitorBrightnessLimits,
              bounded - withOffset,
            ),
          if (rounding.abs() >= 0.005)
            _change(LucideIcons.hash, l10n.calculationRounding, rounding),
          const TextSpan(
            text: '\n────────────────────────\n',
            style: TextStyle(color: Colors.white10),
          ),
          _buildRow(
            icon: LucideIcons.checkCircle2,
            label: l10n.brightnessTarget.toUpperCase(),
            value: '$rounded%',
            iconColor: const Color(0xFF34D399),
            isBold: true,
          ),
          for (final applied in appliedValues)
            if (applied.value.round() != rounded)
              _buildRow(
                icon: LucideIcons.monitor,
                label: '${l10n.brightnessApplied} [${applied.name}]',
                value: '${applied.value.round()}%',
                iconColor: const Color(0xFF94A3B8),
              ),
          if (appliedBrightness != null &&
              appliedBrightness!.round() != rounded)
            _buildRow(
              icon: LucideIcons.monitor,
              label: l10n.brightnessApplied,
              value: '${appliedBrightness!.round()}%',
              iconColor: const Color(0xFF94A3B8),
            ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95), // Slate-900
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      preferBelow: false,
      child: child,
    );
  }

  TextSpan _change(IconData icon, String label, double value) => _buildRow(
    icon: icon,
    label: label,
    value: '${formatBrightnessValue(value, signed: true)}%',
    iconColor: const Color(0xFF94A3B8),
  );

  String _sourceLabel(AppLocalizations l10n) => switch (target.source) {
    BrightnessSource.solarPhases => phaseBaseLabel(l10n, target.data.basePhase),
    BrightnessSource.curve => '${l10n.sunBase} [${_getPresetName(l10n)}]',
    BrightnessSource.appCurve =>
      '${l10n.brightnessSourceApplication(target.applicationName ?? '')} / ${l10n.sunBase} [${_getPresetName(l10n)}]',
    BrightnessSource.appFixed => l10n.brightnessSourceApplication(
      target.applicationName ?? '',
    ),
    BrightnessSource.game => l10n.brightnessSourceGame,
    BrightnessSource.manual => l10n.brightnessSourceManual,
  };

  String _getPresetName(AppLocalizations l10n) {
    if (target.userPresetName != null) {
      return target.userPresetName!;
    }
    switch (target.systemPreset) {
      case PresetType.brightest:
        return l10n.presetBrightest;
      case PresetType.bright:
        return l10n.presetBright;
      case PresetType.dim:
        return l10n.presetDim;
      case PresetType.dimmest:
        return l10n.presetDimmest;
      case PresetType.custom:
        return l10n.presetCustom;
      default:
        return l10n.presetBright;
    }
  }

  TextSpan _buildRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool isBold = false,
  }) {
    return TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(icon, size: 14, color: iconColor),
          ),
        ),
        TextSpan(
          text: '$label: ',
          style: TextStyle(
            color: isBold ? Colors.white : Colors.white70,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        TextSpan(
          text: value,
          style: TextStyle(
            color: isBold ? const Color(0xFF34D399) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const TextSpan(text: '\n'),
      ],
    );
  }
}
