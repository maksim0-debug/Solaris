import 'package:equatable/equatable.dart';
import 'package:solaris/models/solar_phases_config.dart';

enum SolarTargetPhase { night, sunrise, day, sunset }

/// The actual configured phase or transition used by the base calculation.
class SolarPhaseBlend extends Equatable {
  const SolarPhaseBlend(this.from, this.to, this.progress);
  const SolarPhaseBlend.at(SolarTargetPhase phase) : this(phase, phase, 0);

  final SolarTargetPhase from;
  final SolarTargetPhase to;
  final double progress;

  bool get isTransition => from != to;

  PhaseTarget _target(SolarPhasesConfig config, SolarTargetPhase phase) =>
      switch (phase) {
        SolarTargetPhase.night => config.night,
        SolarTargetPhase.sunrise => config.sunrise,
        SolarTargetPhase.day => config.day,
        SolarTargetPhase.sunset => config.sunset,
      };

  double brightness(SolarPhasesConfig config) {
    final start = _target(config, from).brightness;
    return start + (_target(config, to).brightness - start) * progress;
  }

  double temperature(SolarPhasesConfig config) {
    final start = _target(config, from).temperature;
    return start + (_target(config, to).temperature - start) * progress;
  }

  @override
  List<Object?> get props => [from, to, progress];
}
