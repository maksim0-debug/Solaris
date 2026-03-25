import 'package:equatable/equatable.dart';

/// Immutable model representing solar phase timings for a specific day.
class SolarPhaseModel extends Equatable {
  /// Astronomical sunrise.
  final DateTime sunrise;

  /// Astronomical sunset.
  final DateTime sunset;

  /// The start of the morning golden hour.
  final DateTime goldenHourMorning;

  /// The end of the morning golden hour.
  final DateTime goldenHourMorningEnd;

  /// The start of the evening golden hour.
  final DateTime goldenHourEvening;

  /// The end of the evening golden hour.
  final DateTime goldenHourEveningEnd;

  /// The start of the civil twilight (dawn).
  final DateTime civilTwilightBegin;

  /// The end of the civil twilight (dusk).
  final DateTime civilTwilightEnd;

  /// Astronomical dawn.
  final DateTime astronomicalDawn;

  /// Civil dusk.
  final DateTime civilDusk;

  /// Solar noon (zenith).
  final DateTime solarNoon;

  /// Astronomical dusk.
  final DateTime astronomicalDusk;

  const SolarPhaseModel({
    required this.sunrise,
    required this.sunset,
    required this.goldenHourMorning,
    required this.goldenHourMorningEnd,
    required this.goldenHourEvening,
    required this.goldenHourEveningEnd,
    required this.civilTwilightBegin,
    required this.civilTwilightEnd,
    required this.astronomicalDawn,
    required this.civilDusk,
    required this.solarNoon,
    required this.astronomicalDusk,
  });

  @override
  List<Object?> get props => [
    sunrise,
    sunset,
    goldenHourMorning,
    goldenHourMorningEnd,
    goldenHourEvening,
    goldenHourEveningEnd,
    civilTwilightBegin,
    civilTwilightEnd,
    astronomicalDawn,
    civilDusk,
    solarNoon,
    astronomicalDusk,
  ];
}
