import 'package:fl_chart/fl_chart.dart';

enum PresetType {
  brightest(0.3),
  bright(0.6),
  dim(0.9),
  dimmest(1.0),
  custom(1.0);

  final double weatherSensitivity;

  const PresetType(this.weatherSensitivity);

  String toJson() => name;
  static PresetType fromJson(String json) => PresetType.values.firstWhere(
    (e) => e.name == json,
    orElse: () => PresetType.custom,
  );
}

enum TemperaturePresetType {
  coolest,
  cool,
  warm,
  warmest,
  custom;

  String toJson() => name;
  static TemperaturePresetType fromJson(String json) =>
      TemperaturePresetType.values.firstWhere(
        (e) => e.name == json,
        orElse: () => TemperaturePresetType.custom,
      );
}

class PresetConstants {
  static List<FlSpot> getDefaultPoints(PresetType type) {
    switch (type) {
      case PresetType.brightest:
        return const [
          FlSpot(-20, 40),
          FlSpot(-6, 60),
          FlSpot(0, 80),
          FlSpot(10, 95),
          FlSpot(30, 100),
          FlSpot(90, 100),
        ];
      case PresetType.bright:
        return const [
          FlSpot(-20, 15),
          FlSpot(-6, 25),
          FlSpot(0, 60),
          FlSpot(10, 85),
          FlSpot(30, 100),
          FlSpot(90, 100),
        ];
      case PresetType.dim:
        return const [
          FlSpot(-20, 5),
          FlSpot(-6, 15),
          FlSpot(0, 40),
          FlSpot(10, 60),
          FlSpot(30, 80),
          FlSpot(90, 80),
        ];
      case PresetType.dimmest:
        return const [
          FlSpot(-20, 0),
          FlSpot(-6, 5),
          FlSpot(0, 20),
          FlSpot(10, 40),
          FlSpot(30, 60),
          FlSpot(90, 60),
        ];
      case PresetType.custom:
        return const [
          FlSpot(-20, 50),
          FlSpot(-6, 50),
          FlSpot(0, 50),
          FlSpot(10, 50),
          FlSpot(30, 50),
          FlSpot(90, 50),
        ];
    }
  }

  static Map<PresetType, List<FlSpot>> getAllDefaults() {
    return {for (var type in PresetType.values) type: getDefaultPoints(type)};
  }

  static List<FlSpot> getTemperatureDefaultPoints(TemperaturePresetType type) {
    // For temperature, higher sun usually means higher Kelvin (bluer),
    // and lower sun means lower Kelvin (warmer/yellower).
    switch (type) {
      case TemperaturePresetType.coolest:
        return const [
          FlSpot(-20, 4500),
          FlSpot(-6, 5000),
          FlSpot(0, 5500),
          FlSpot(10, 6000),
          FlSpot(30, 6500),
          FlSpot(90, 6500),
        ];
      case TemperaturePresetType.cool:
        return const [
          FlSpot(-20, 3500),
          FlSpot(-6, 4000),
          FlSpot(0, 4500),
          FlSpot(10, 5500),
          FlSpot(30, 6500),
          FlSpot(90, 6500),
        ];
      case TemperaturePresetType.warm:
        return const [
          FlSpot(-20, 3300),
          FlSpot(-6, 3300),
          FlSpot(0, 4000),
          FlSpot(10, 5000),
          FlSpot(30, 6500),
          FlSpot(90, 6500),
        ];
      case TemperaturePresetType.warmest:
        return const [
          FlSpot(-20, 3300),
          FlSpot(-6, 3300),
          FlSpot(0, 3300),
          FlSpot(10, 4500),
          FlSpot(30, 6000),
          FlSpot(90, 6500),
        ];
      case TemperaturePresetType.custom:
        return const [
          FlSpot(-20, 3500),
          FlSpot(-6, 3500),
          FlSpot(0, 5000),
          FlSpot(10, 5000),
          FlSpot(30, 6500),
          FlSpot(90, 6500),
        ];
    }
  }

  static Map<TemperaturePresetType, List<FlSpot>> getAllTemperatureDefaults() {
    return {
      for (var type in TemperaturePresetType.values)
        type: getTemperatureDefaultPoints(type),
    };
  }
}
