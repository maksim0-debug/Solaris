import 'package:flutter/material.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'package:solaris/models/solar_state.dart';
import 'package:solaris/services/sun_calculator_service.dart';

class StatusConfig {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;

  StatusConfig({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class StatusHelper {
  static ({Duration duration, SolarEventType type})? getUpcomingEvent(
    SolarState state,
    DateTime now,
  ) {
    if (!state.phases.isForDate(now)) return null;
    return SunCalculatorService().getNextEvent(state.phases, now);
  }

  static Duration getRemainingDuration(SolarState state, DateTime now) {
    final service = SunCalculatorService();
    // The clock can advance before the solar stream publishes its new phase.
    if (!state.phases.isForDate(now) ||
        !now.isBefore(state.phases.nextDayCivilTwilightBegin) ||
        service.getCurrentPhase(state.phases, now) != state.currentPhase) {
      return Duration.zero;
    }
    return service.getTimeUntilPhaseEnd(state.phases, now);
  }

  static StatusConfig getStatus(
    SolarState state,
    AppLocalizations l10n,
    bool isAutoBright,
    bool isAutoTemp,
    DateTime now,
  ) {
    final phase = state.currentPhase;
    final isAdaptive = isAutoBright || isAutoTemp;
    final modeTitle = isAdaptive ? l10n.statusAdaptive : l10n.statusManual;

    // Default values
    String title = l10n.calculating;
    String description = l10n.updatingSolarData;
    IconData icon = LucideIcons.sun;
    Color color = const Color(0xFFFDBA74);

    switch (phase) {
      case CurrentDayPhase.deepNight:
        title = l10n.phaseDeepNight;
        description = isAutoBright
            ? l10n.descDeepNightAuto
            : l10n.descDeepNightManual;
        icon = LucideIcons.moon;
        color = const Color(0xFF818CF8); // Indigo-400
        break;

      case CurrentDayPhase.dawn:
        title = l10n.phaseDawn;
        description = isAutoBright ? l10n.descDawnAuto : l10n.descDawnManual;
        icon = LucideIcons.sunrise;
        color = const Color(0xFF94A3B8); // Slate-400
        break;

      case CurrentDayPhase.morningSpike:
        title = l10n.phaseMorningSpike;
        description = isAutoBright
            ? l10n.descMorningSpikeAuto
            : l10n.descMorningSpikeManual;
        icon = LucideIcons.sunrise;
        color = const Color(0xFFFB923C); // Orange-400
        break;

      case CurrentDayPhase.zenith:
        title = l10n.phaseZenith;
        description = isAutoBright
            ? l10n.descZenithAuto
            : l10n.descZenithManual;
        icon = LucideIcons.sun;
        color = const Color(0xFFFDE047); // Yellow-300
        break;

      case CurrentDayPhase.day:
        title = l10n.phaseDay;
        description = isAutoBright ? l10n.descDayAuto : l10n.descDayManual;
        icon = LucideIcons.sun;
        color = const Color(0xFFFDE047);
        break;

      case CurrentDayPhase.goldenHour:
        title = l10n.phaseGoldenHour;
        final isMorning = now.isBefore(state.phases.solarNoon);
        if (isMorning) {
          description = isAutoTemp
              ? (isAutoBright
                    ? l10n.descGoldenHourMorningBothAuto
                    : l10n.descGoldenHourMorningTempOnly)
              : (isAutoBright
                    ? l10n.descGoldenHourMorningBrightOnly
                    : l10n.descGoldenHourMorningManual);
        } else {
          description = isAutoTemp
              ? (isAutoBright
                    ? l10n.descGoldenHourEveningBothAuto
                    : l10n.descGoldenHourEveningTempOnly)
              : (isAutoBright
                    ? l10n.descGoldenHourEveningBrightOnly
                    : l10n.descGoldenHourEveningManual);
        }
        icon = LucideIcons.sparkles;
        color = const Color(0xFFFDBA74); // Amber-300
        break;

      case CurrentDayPhase.twilight:
        title = l10n.phaseTwilight;
        description = isAutoBright
            ? l10n.descTwilightAuto
            : l10n.descTwilightManual;
        icon = LucideIcons.sunset;
        color = const Color(0xFF94A3B8); // Slate-400
        break;
    }

    return StatusConfig(
      title: title,
      subtitle: modeTitle.toUpperCase(),
      description: description,
      icon: icon,
      color: color,
    );
  }
}
