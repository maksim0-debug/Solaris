import 'package:equatable/equatable.dart';
import 'package:solaris/constants/temperature_constants.dart';

class PhaseTarget extends Equatable {
  final double brightness; // 0..100%
  final int temperature; // 1000..6500K

  const PhaseTarget({required this.brightness, required this.temperature});

  PhaseTarget copyWith({double? brightness, int? temperature}) {
    return PhaseTarget(
      brightness: (brightness ?? this.brightness).clamp(0.0, 100.0),
      temperature: (temperature ?? this.temperature).clamp(
        TemperatureConstants.min,
        TemperatureConstants.max,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'brightness': brightness,
    'temperature': temperature,
  };

  factory PhaseTarget.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PhaseTarget(
        brightness: 50.0,
        temperature: TemperatureConstants.max,
      );
    }
    return PhaseTarget(
      brightness: ((json['brightness'] as num?)?.toDouble() ?? 50.0).clamp(
        0.0,
        100.0,
      ),
      temperature:
          ((json['temperature'] as num?)?.toInt() ?? TemperatureConstants.max)
              .clamp(TemperatureConstants.min, TemperatureConstants.max),
    );
  }

  @override
  List<Object?> get props => [brightness, temperature];
}

class SolarPhasesConfig extends Equatable {
  final PhaseTarget night;
  final PhaseTarget sunrise;
  final PhaseTarget day;
  final PhaseTarget sunset;

  const SolarPhasesConfig({
    required this.night,
    required this.sunrise,
    required this.day,
    required this.sunset,
  });

  SolarPhasesConfig copyWith({
    PhaseTarget? night,
    PhaseTarget? sunrise,
    PhaseTarget? day,
    PhaseTarget? sunset,
  }) {
    return SolarPhasesConfig(
      night: night ?? this.night,
      sunrise: sunrise ?? this.sunrise,
      day: day ?? this.day,
      sunset: sunset ?? this.sunset,
    );
  }

  static const SolarPhasesConfig defaultBalanced = SolarPhasesConfig(
    night: PhaseTarget(brightness: 15.0, temperature: 2200),
    sunrise: PhaseTarget(brightness: 40.0, temperature: 4000),
    day: PhaseTarget(brightness: 100.0, temperature: 6500),
    sunset: PhaseTarget(brightness: 35.0, temperature: 3000),
  );

  Map<String, dynamic> toJson() => {
    'night': night.toJson(),
    'sunrise': sunrise.toJson(),
    'day': day.toJson(),
    'sunset': sunset.toJson(),
  };

  factory SolarPhasesConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaultBalanced;
    return SolarPhasesConfig(
      night: json['night'] != null
          ? PhaseTarget.fromJson(json['night'] as Map<String, dynamic>)
          : defaultBalanced.night,
      sunrise: json['sunrise'] != null
          ? PhaseTarget.fromJson(json['sunrise'] as Map<String, dynamic>)
          : defaultBalanced.sunrise,
      day: json['day'] != null
          ? PhaseTarget.fromJson(json['day'] as Map<String, dynamic>)
          : defaultBalanced.day,
      sunset: json['sunset'] != null
          ? PhaseTarget.fromJson(json['sunset'] as Map<String, dynamic>)
          : defaultBalanced.sunset,
    );
  }

  /// Returns whether this configuration differs from [defaultBalanced] for
  /// either temperature or brightness depending on [isTemp].
  bool isModified({required bool isTemp}) {
    const def = defaultBalanced;
    if (isTemp) {
      return night.temperature != def.night.temperature ||
          sunrise.temperature != def.sunrise.temperature ||
          day.temperature != def.day.temperature ||
          sunset.temperature != def.sunset.temperature;
    } else {
      return (night.brightness - def.night.brightness).abs() > 0.05 ||
          (sunrise.brightness - def.sunrise.brightness).abs() > 0.05 ||
          (day.brightness - def.day.brightness).abs() > 0.05 ||
          (sunset.brightness - def.sunset.brightness).abs() > 0.05;
    }
  }

  /// Resets the targets of this configuration to [defaultBalanced] for
  /// either temperature or brightness depending on [isTemp], while preserving
  /// the custom values of the other metric.
  SolarPhasesConfig resetToDefault({required bool isTemp}) {
    const def = defaultBalanced;
    if (isTemp) {
      return copyWith(
        night: night.copyWith(temperature: def.night.temperature),
        sunrise: sunrise.copyWith(temperature: def.sunrise.temperature),
        day: day.copyWith(temperature: def.day.temperature),
        sunset: sunset.copyWith(temperature: def.sunset.temperature),
      );
    } else {
      return copyWith(
        night: night.copyWith(brightness: def.night.brightness),
        sunrise: sunrise.copyWith(brightness: def.sunrise.brightness),
        day: day.copyWith(brightness: def.day.brightness),
        sunset: sunset.copyWith(brightness: def.sunset.brightness),
      );
    }
  }

  @override
  List<Object?> get props => [night, sunrise, day, sunset];
}
