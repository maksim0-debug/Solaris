import 'package:flutter/material.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'package:solaris/models/solar_state.dart';

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
  static StatusConfig getStatus(
    SolarState state,
    AppLocalizations l10n,
    bool isAuto,
  ) {
    final phase = state.currentPhase;
    final modeTitle = isAuto ? l10n.statusAdaptive : l10n.statusManual;

    // Default values
    String title = l10n.calculating;
    String description = l10n.updatingSolarData;
    IconData icon = LucideIcons.sun;
    Color color = const Color(0xFFFDBA74);

    switch (phase) {
      case CurrentDayPhase.deepNight:
        title = l10n.phaseDeepNight;
        description = isAuto
            ? l10n.descDeepNightAuto
            : l10n.descDeepNightManual;
        icon = LucideIcons.moon;
        color = const Color(0xFF818CF8); // Indigo-400
        break;
      
      case CurrentDayPhase.dawn:
        title = l10n.phaseDawn;
        description = isAuto
            ? l10n.descDawnAuto
            : l10n.descDawnManual;
        icon = LucideIcons.sunrise;
        color = const Color(0xFF94A3B8); // Slate-400
        break;

      case CurrentDayPhase.morningSpike:
        title = l10n.phaseMorningSpike;
        description = isAuto
            ? l10n.descMorningSpikeAuto
            : l10n.descMorningSpikeManual;
        icon = LucideIcons.sunrise;
        color = const Color(0xFFFB923C); // Orange-400
        break;

      case CurrentDayPhase.zenith:
        title = l10n.phaseZenith;
        description = isAuto ? l10n.descZenithAuto : l10n.descZenithManual;
        icon = LucideIcons.sun;
        color = const Color(0xFFFDE047); // Yellow-300
        break;

      case CurrentDayPhase.goldenHour:
        title = l10n.phaseGoldenHour;
        description = isAuto
            ? l10n.descGoldenHourAuto
            : l10n.descGoldenHourManual;
        icon = LucideIcons.sparkles;
        color = const Color(0xFFFDBA74); // Amber-300
        break;

      case CurrentDayPhase.twilight:
        title = l10n.phaseTwilight;
        description = isAuto ? l10n.descTwilightAuto : l10n.descTwilightManual;
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
