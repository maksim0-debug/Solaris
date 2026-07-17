import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/widgets/weather_icon_helper.dart';

class TemperatureBreakdownTooltip extends StatelessWidget {
  const TemperatureBreakdownTooltip({
    super.key,
    required this.child,
    required this.smartData,
    required this.currentTemperature,
    required this.isSmartCircadianEnabled,
  });

  final Widget child;
  final SmartCircadianData smartData;
  final int currentTemperature;
  final bool isSmartCircadianEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final int baseTemp = smartData.baseTemperature > 0 ? smartData.baseTemperature : 6500;
    final int weatherImpact = smartData.weatherTemperatureImpact;
    
    final int sleepPressureImpact = isSmartCircadianEnabled ? smartData.sleepPressureTemperatureImpact : 0;
    final int windDownImpact = isSmartCircadianEnabled ? smartData.windDownTemperatureImpact : 0;
    final int sleepDebtImpact = isSmartCircadianEnabled ? smartData.sleepDebtTemperatureImpact : 0;

    return Tooltip(
      richMessage: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.5,
          fontFamily: 'Outfit',
        ),
        children: [
          _buildRow(
            icon: LucideIcons.sun,
            label: '${l10n.temperatureBreakdownBase} [${_getPresetName(l10n, smartData)}]'.toUpperCase(),
            value: '${baseTemp} K',
            iconColor: const Color(0xFF818CF8), // Blue-Indigo for temp base
          ),
          if (weatherImpact.abs() > 0.5)
            _buildRow(
              icon: getWeatherIcon(smartData.weatherCode),
              label: l10n.temperatureBreakdownWeather,
              value: '${weatherImpact} K',
              iconColor: const Color(0xFF94A3B8),
            ),
          if (isSmartCircadianEnabled && sleepPressureImpact.abs() > 0.5)
            _buildRow(
              icon: LucideIcons.hourglass,
              label: l10n.temperatureBreakdownSleepPressure,
              value: '${sleepPressureImpact} K',
              iconColor: const Color(0xFFA78BFA),
            ),
          if (isSmartCircadianEnabled && windDownImpact.abs() > 0.5)
            _buildRow(
              icon: LucideIcons.moon,
              label: l10n.temperatureBreakdownWindDown,
              value: '${windDownImpact} K',
              iconColor: const Color(0xFF818CF8),
            ),
          if (isSmartCircadianEnabled && sleepDebtImpact.abs() > 0.5)
            _buildRow(
              icon: LucideIcons.battery,
              label: l10n.temperatureBreakdownSleepDebt,
              value: '${sleepDebtImpact} K',
              iconColor: const Color(0xFFF43F5E),
            ),
          const TextSpan(
            text: '\n────────────────────────\n',
            style: TextStyle(color: Colors.white10),
          ),
          _buildRow(
            icon: LucideIcons.checkCircle2,
            label: l10n.temperatureBreakdownFinal.toUpperCase(),
            value: '${currentTemperature} K',
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
    if (data.activeUserTemperaturePresetName != null) {
      return data.activeUserTemperaturePresetName!;
    }
    switch (data.activeSystemTemperaturePreset) {
      case TemperaturePresetType.coolest:
        return l10n.tempCoolest;
      case TemperaturePresetType.cool:
        return l10n.tempCool;
      case TemperaturePresetType.warm:
        return l10n.tempWarm;
      case TemperaturePresetType.warmest:
        return l10n.tempWarmest;
      case TemperaturePresetType.custom:
        return l10n.tempCustom;
      default:
        return l10n.tempCool;
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
