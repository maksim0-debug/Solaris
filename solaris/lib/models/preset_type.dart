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
  static PresetType fromJson(String json) =>
      PresetType.values.firstWhere((e) => e.name == json, orElse: () => PresetType.custom);
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
    return {
      for (var type in PresetType.values) type: getDefaultPoints(type),
    };
  }
}
