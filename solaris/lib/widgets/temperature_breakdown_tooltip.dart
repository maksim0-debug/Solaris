import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/models/temperature_target.dart';
import 'package:solaris/widgets/phase_base_label.dart';
import 'package:solaris/widgets/weather_icon_helper.dart';

class TemperatureBreakdownTooltip extends StatelessWidget {
  const TemperatureBreakdownTooltip({
    super.key,
    required this.child,
    required this.smartData,
    required this.currentTemperature,
    required this.isSmartCircadianEnabled,
    this.circadianMode = CircadianMode.normalizedCurve,
    this.target,
    this.monitorName,
    this.isMonitorGroup = false,
    this.appliedTemperature,
    this.appliedValues = const [],
  });

  final Widget child;
  final SmartCircadianData smartData;
  final int currentTemperature;
  final bool isSmartCircadianEnabled;
  final CircadianMode circadianMode;
  final TemperatureTarget? target;
  final String? monitorName;
  final bool isMonitorGroup;
  final int? appliedTemperature;
  final List<({String name, num value})> appliedValues;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final int baseTemp = smartData.baseTemperature > 0
        ? smartData.baseTemperature
        : 6500;
    final int weatherImpact = smartData.weatherTemperatureImpact;

    final int timeShiftImpact = isSmartCircadianEnabled
        ? smartData.timeShiftTemperatureImpact
        : 0;
    final int sleepPressureImpact = isSmartCircadianEnabled
        ? smartData.sleepPressureTemperatureImpact
        : 0;
    final int windDownImpact = isSmartCircadianEnabled
        ? smartData.windDownTemperatureImpact
        : 0;
    final int sleepDebtImpact = isSmartCircadianEnabled
        ? smartData.sleepDebtTemperatureImpact
        : 0;

    final int displayedFinalTemp = smartData.finalTemperature > 0
        ? smartData.finalTemperature
        : currentTemperature;

    return Tooltip(
      richMessage: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.5,
          fontFamily: 'Outfit',
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
            value: '$baseTemp K',
            iconColor: const Color(0xFF818CF8), // Blue-Indigo for temp base
          ),
          if (weatherImpact.abs() > 0.5)
            _buildRow(
              icon: getWeatherIcon(smartData.weatherCode),
              label: l10n.temperatureBreakdownWeather,
              value: '$weatherImpact K',
              iconColor: const Color(0xFF94A3B8),
            ),
          if (isSmartCircadianEnabled &&
              (timeShiftImpact.abs() > 0.5 || smartData.isTimeShiftActive))
            _buildRow(
              icon: LucideIcons.sunrise,
              label: l10n.featureTimeShift,
              value:
                  '${timeShiftImpact > 0 ? '+$timeShiftImpact' : timeShiftImpact} K',
              iconColor: const Color(0xFFF59E0B),
            ),
          if (isSmartCircadianEnabled && sleepPressureImpact.abs() > 0.5)
            _buildRow(
              icon: LucideIcons.hourglass,
              label: l10n.temperatureBreakdownSleepPressure,
              value: '$sleepPressureImpact K',
              iconColor: const Color(0xFFA78BFA),
            ),
          if (isSmartCircadianEnabled && windDownImpact.abs() > 0.5)
            _buildRow(
              icon: LucideIcons.moon,
              label: l10n.temperatureBreakdownWindDown,
              value: '$windDownImpact K',
              iconColor: const Color(0xFF818CF8),
            ),
          if (isSmartCircadianEnabled && sleepDebtImpact.abs() > 0.5)
            _buildRow(
              icon: LucideIcons.battery,
              label: l10n.temperatureBreakdownSleepDebt,
              value: '$sleepDebtImpact K',
              iconColor: const Color(0xFFF43F5E),
            ),
          if (smartData.temperatureLimitImpact != 0)
            _buildRow(
              icon: LucideIcons.slidersHorizontal,
              label: l10n.temperatureCalculationLimit,
              value:
                  '${smartData.temperatureLimitImpact > 0 ? '+' : ''}${smartData.temperatureLimitImpact} K',
              iconColor: const Color(0xFF94A3B8),
            ),
          if (smartData.temperatureRoundingImpact != 0)
            _buildRow(
              icon: LucideIcons.hash,
              label: l10n.calculationRounding,
              value:
                  '${smartData.temperatureRoundingImpact > 0 ? '+' : ''}${smartData.temperatureRoundingImpact} K',
              iconColor: const Color(0xFF94A3B8),
            ),
          const TextSpan(
            text: '\n────────────────────────\n',
            style: TextStyle(color: Colors.white10),
          ),
          _buildRow(
            icon: LucideIcons.checkCircle2,
            label: l10n.temperatureBreakdownFinal.toUpperCase(),
            value: '$displayedFinalTemp K',
            iconColor: const Color(0xFF34D399),
            isBold: true,
          ),
          for (final applied in appliedValues)
            if (applied.value.round() != displayedFinalTemp)
              _buildRow(
                icon: LucideIcons.monitor,
                label: '${l10n.temperatureApplied} [${applied.name}]',
                value: '${applied.value.round()} K',
                iconColor: const Color(0xFF94A3B8),
              ),
          if (appliedTemperature != null &&
              appliedTemperature != displayedFinalTemp)
            _buildRow(
              icon: LucideIcons.monitor,
              label: l10n.temperatureApplied,
              value: '$appliedTemperature K',
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

  String _sourceLabel(AppLocalizations l10n) {
    final source = target?.source;
    if (source == TemperatureSource.appFixed) {
      return l10n.temperatureSourceApplication(target!.applicationName ?? '');
    }
    if (source == TemperatureSource.game) return l10n.temperatureSourceGame;
    if (source == TemperatureSource.manual) return l10n.temperatureSourceManual;
    if (source == TemperatureSource.disabled) {
      return l10n.temperatureSourceDisabled;
    }
    if (source == TemperatureSource.solarPhases ||
        (source == null && circadianMode == CircadianMode.solarPhases)) {
      return phaseBaseLabel(l10n, smartData.basePhase, temperature: true);
    }
    final curve =
        '${l10n.temperatureBreakdownBase} [${_getPresetName(l10n, smartData)}]';
    return source == TemperatureSource.appCurve
        ? '${l10n.temperatureSourceApplication(target!.applicationName ?? '')} / $curve'
        : curve;
  }

  String _getPresetName(AppLocalizations l10n, SmartCircadianData data) {
    final userName = target != null
        ? target!.userPresetName
        : data.activeUserTemperaturePresetName;
    if (userName != null) return userName;
    switch (target != null
        ? target!.systemPreset
        : data.activeSystemTemperaturePreset) {
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
