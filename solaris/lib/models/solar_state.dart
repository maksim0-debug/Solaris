import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/current_day_phase.dart';

/// Data class representing the current solar state for the UI.
class SolarState {
  final SolarPhaseModel phases;
  final CurrentDayPhase currentPhase;
  final Duration timeUntilNextEvent;
  final SolarEventType nextEventType;
  final double sunElevation;
  final double sunAzimuth;
  final double sunZenith;
  final double sunProgress;
  final double uvIndex;
  final double spectralIntensity;
  final String azimuthTrend;
  final String elevationTrend;

  SolarState({
    required this.phases,
    required this.currentPhase,
    required this.timeUntilNextEvent,
    required this.nextEventType,
    required this.sunElevation,
    required this.sunAzimuth,
    required this.sunZenith,
    required this.sunProgress,
    required this.uvIndex,
    required this.spectralIntensity,
    required this.azimuthTrend,
    required this.elevationTrend,
  });
}
