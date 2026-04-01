import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/smart_circadian_data.dart';

class CircadianBreakdownTooltip extends StatelessWidget {
  const CircadianBreakdownTooltip({
    super.key,
    required this.child,
    required this.smartData,
    required this.currentBrightness,
  });

  final Widget child;
  final SmartCircadianData smartData;
  final double currentBrightness;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Tooltip(
      richMessage: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.5,
          fontFamily: 'Outfit', // Consistent with AppTheme
        ),
        children: [
          _buildRow(
            icon: LucideIcons.sun,
            label: '${l10n.sunBase} [${_getPresetName(l10n, smartData)}]'.toUpperCase(),
            value: '${smartData.baseBrightness.round()}%',
            iconColor: const Color(0xFFFDBA74),
          ),
          if (smartData.weatherAbsoluteImpact > 0.5)
            _buildRow(
              icon: _getWeatherIcon(smartData.weatherCode),
              label: l10n.weatherAdjustmentTitle,
              value: '-${smartData.weatherAbsoluteImpact.round()}%',
              iconColor: const Color(0xFF94A3B8),
            ),
          if (smartData.windDownAbsoluteImpact > 0.5)
            _buildRow(
              icon: LucideIcons.moon,
              label: l10n.featureWindDownShort,
              value: '-${smartData.windDownAbsoluteImpact.round()}%',
              iconColor: const Color(0xFF818CF8),
            ),
          if (smartData.sleepPressureAbsoluteImpact > 0.5)
            _buildRow(
              icon: LucideIcons.brain,
              label: l10n.featureSleepPressureShort,
              value: '-${smartData.sleepPressureAbsoluteImpact.round()}%',
              iconColor: const Color(0xFFF472B6),
            ),
          if (smartData.sleepDebtAbsoluteImpact > 0.5)
            _buildRow(
              icon: LucideIcons.battery,
              label: l10n.featureSleepDebtShort,
              value: '-${smartData.sleepDebtAbsoluteImpact.round()}%',
              iconColor: const Color(0xFF60A5FA),
            ),
          const TextSpan(text: '\n'),
          WidgetSpan(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              height: 1,
              width: 160,
              color: Colors.white10,
            ),
          ),
          const TextSpan(text: '\n'),
          _buildRow(
            icon: LucideIcons.checkCircle,
            label: l10n.finalValue.toUpperCase(),
            value: '${currentBrightness.round()}%',
            iconColor: const Color(0xFFFDBA74),
            isBold: true,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      preferBelow: false,
      child: child,
    );
  }

  String _getPresetName(AppLocalizations l10n, SmartCircadianData smartData) {
    if (smartData.activeUserPresetName != null) {
      return smartData.activeUserPresetName!;
    }
    if (smartData.activeSystemPreset != null) {
      switch (smartData.activeSystemPreset!) {
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
      }
    }
    return '';
  }

  InlineSpan _buildRow({
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
            color: Colors.white70,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        TextSpan(
          text: value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const TextSpan(text: '\n'),
      ],
    );
  }

  IconData _getWeatherIcon(int? code) {
    if (code == null) return LucideIcons.cloud;
    if (code == 0) return LucideIcons.sun;
    if (code >= 1 && code <= 2) return LucideIcons.cloudSun;
    if (code == 3) return LucideIcons.cloud;
    if (code == 45 || code == 48) return LucideIcons.cloudFog;
    if (code >= 51 && code <= 55) return LucideIcons.cloudDrizzle;
    if (code >= 56 && code <= 57) return LucideIcons.snowflake;
    if (code >= 61 && code <= 63) return LucideIcons.cloudRain;
    if (code == 65) return LucideIcons.cloudRainWind;
    if (code >= 66 && code <= 67) return LucideIcons.cloudRain;
    if (code >= 71 && code <= 77) return LucideIcons.snowflake;
    if (code >= 80 && code <= 81) return LucideIcons.cloudRain;
    if (code == 82) return LucideIcons.cloudRainWind;
    if (code >= 85 && code <= 86) return LucideIcons.snowflake;
    if (code >= 95 && code <= 99) return LucideIcons.cloudLightning;
    return LucideIcons.cloud;
  }
}
