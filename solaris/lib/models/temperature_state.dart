import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/preset_type.dart';

class TemperatureState {
  final TemperaturePresetType activePreset;
  final Map<TemperaturePresetType, List<FlSpot>> curvesMap;
  final bool isEnabled;

  TemperatureState({
    this.activePreset = TemperaturePresetType.cool,
    Map<TemperaturePresetType, List<FlSpot>>? curvesMap,
    this.isEnabled = false,
  }) : curvesMap = curvesMap ?? PresetConstants.getAllTemperatureDefaults();

  List<FlSpot> get curvePoints => curvesMap[activePreset]!;

  TemperatureState copyWith({
    TemperaturePresetType? activePreset,
    Map<TemperaturePresetType, List<FlSpot>>? curvesMap,
    bool? isEnabled,
  }) {
    return TemperatureState(
      activePreset: activePreset ?? this.activePreset,
      curvesMap: curvesMap ?? this.curvesMap,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activePreset': activePreset.toJson(),
      'isEnabled': isEnabled,
      'curvesMap': curvesMap.map(
        (key, value) => MapEntry(
          key.toJson(),
          value.map((e) => {'x': e.x, 'y': e.y}).toList(),
        ),
      ),
    };
  }

  factory TemperatureState.fromJson(Map<String, dynamic> json) {
    Map<TemperaturePresetType, List<FlSpot>> parsedCurvesMap =
        PresetConstants.getAllTemperatureDefaults();

    if (json.containsKey('curvesMap')) {
      final mapData = json['curvesMap'] as Map<String, dynamic>;
      mapData.forEach((key, value) {
        if (value is! List) return;
        final preset = TemperaturePresetType.fromJson(key);
        final pointsData = value;
        parsedCurvesMap[preset] = pointsData
            .whereType<Map<String, dynamic>>()
            .map(
              (point) => FlSpot(
                (point['x'] as num).toDouble(),
                (point['y'] as num).toDouble(),
              ),
            )
            .toList();
      });
    }

    return TemperatureState(
      activePreset: json['activePreset'] != null
          ? TemperaturePresetType.fromJson(json['activePreset'].toString())
          : TemperaturePresetType.cool,
      isEnabled: json['isEnabled'] == true,
      curvesMap: parsedCurvesMap,
    );
  }
}
