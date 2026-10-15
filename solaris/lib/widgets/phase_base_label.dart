import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/solar_phase_blend.dart';

String _phaseName(AppLocalizations l10n, SolarTargetPhase phase) =>
    switch (phase) {
      SolarTargetPhase.night => l10n.phaseNight,
      SolarTargetPhase.sunrise => l10n.phaseSunrise,
      SolarTargetPhase.day => l10n.phaseDay,
      SolarTargetPhase.sunset => l10n.phaseSunset,
    };

String phaseBaseLabel(
  AppLocalizations l10n,
  SolarPhaseBlend? phase, {
  bool temperature = false,
}) {
  if (phase == null) {
    return temperature ? l10n.temperaturePhasesBase : l10n.brightnessPhasesBase;
  }
  if (phase.isTransition) {
    final transition =
        '${_phaseName(l10n, phase.from)} → ${_phaseName(l10n, phase.to)}';
    return temperature
        ? l10n.temperatureBaseTransition(transition)
        : l10n.brightnessBaseTransition(transition);
  }
  return switch ((temperature, phase.from)) {
    (false, SolarTargetPhase.night) => l10n.brightnessBaseNight,
    (false, SolarTargetPhase.sunrise) => l10n.brightnessBaseSunrise,
    (false, SolarTargetPhase.day) => l10n.brightnessBaseDay,
    (false, SolarTargetPhase.sunset) => l10n.brightnessBaseSunset,
    (true, SolarTargetPhase.night) => l10n.temperatureBaseNight,
    (true, SolarTargetPhase.sunrise) => l10n.temperatureBaseSunrise,
    (true, SolarTargetPhase.day) => l10n.temperatureBaseDay,
    (true, SolarTargetPhase.sunset) => l10n.temperatureBaseSunset,
  };
}
