import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/widgets/weather_icon_helper.dart';

class CircadianBreakdownTooltip extends StatelessWidget {
  const CircadianBreakdownTooltip({
    super.key,
    required this.child,
    required this.smartData,
    required this.currentBrightness,
    required this.isSmartCircadianEnabled,
  });

  final Widget child;
  final SmartCircadianData smartData;
  final double currentBrightness;
  final bool isSmartCircadianEnabled;

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
            label: '${l10n.sunBase} [${_getPresetName(l10n, smartData)}]'
                .toUpperCase(),
            value: '${smartData.baseBrightness.round()}%',
            iconColor: const Color(0xFFFDBA74),
          ),
          if (smartData.weatherAbsoluteImpact > 0.5)
            _buildRow(
              icon: getWeatherIcon(smartData.weatherCode),
              label: l10n.weatherBrightnessAdjustmentTitle,
              value: '-${smartData.weatherAbsoluteImpact.round()}%',
              iconColor: const Color(0xFF94A3B8),
            ),
          if (isSmartCircadianEnabled &&
              smartData.timeShiftBrightnessImpact.abs() > 0.5)
            _buildRow(
              icon: LucideIcons.sunrise,
              label: l10n.featureTimeShiftShort,
              value:
                  '${smartData.timeShiftBrightnessImpact > 0 ? '+' : ''}${smartData.timeShiftBrightnessImpact.round()}%',
              iconColor: const Color(0xFFFDBA74),
            ),
          if (isSmartCircadianEnabled && smartData.windDownAbsoluteImpact > 0.5)
            _buildRow(
              icon: LucideIcons.moon,
              label: l10n.featureWindDownShort,
              value: '-${smartData.windDownAbsoluteImpact.round()}%',
              iconColor: const Color(0xFF818CF8),
            ),
          if (isSmartCircadianEnabled &&
              smartData.sleepPressureAbsoluteImpact > 0.5)
            _buildRow(
              icon: LucideIcons.hourglass,
              label: l10n.featureSleepPressureShort,
              value: '-${smartData.sleepPressureAbsoluteImpact.round()}%',
              iconColor: const Color(0xFFA78BFA),
            ),
          if (isSmartCircadianEnabled &&
              smartData.sleepDebtAbsoluteImpact > 0.5)
            _buildRow(
              icon: LucideIcons.battery,
              label: l10n.featureSleepDebtShort,
              value: '-${smartData.sleepDebtAbsoluteImpact.round()}%',
              iconColor: const Color(0xFFF43F5E),
            ),
          const TextSpan(
            text: '\n────────────────────────\n',
            style: TextStyle(color: Colors.white10),
          ),
          _buildRow(
            icon: LucideIcons.checkCircle2,
            label: l10n.finalValue.toUpperCase(),
            value: '${currentBrightness.round()}%',
            iconColor: const Color(0xFF34D399),
            isBold: true,
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.95), // Slate-900
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      preferBelow: false,
      child: child,
    );
  }

  String _getPresetName(AppLocalizations l10n, SmartCircadianData data) {
    if (data.activeUserPresetName != null) {
      return data.activeUserPresetName!;
    }
    switch (data.activeSystemPreset) {
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
