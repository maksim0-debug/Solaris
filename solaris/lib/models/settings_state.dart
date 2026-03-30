import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/preset_type.dart';

class SettingsState {
  final PresetType activePreset;
  final Map<PresetType, List<FlSpot>> curvesMap;
  final double curveSharpness;
  final bool isAutorunEnabled;
  final bool isWeatherAdjustmentEnabled;
  final bool isAutoBrightnessEnabled;

  SettingsState({
    this.activePreset = PresetType.bright,
    Map<PresetType, List<FlSpot>>? curvesMap,
    this.curveSharpness = 1.0,
    this.isAutorunEnabled = false,
    this.isWeatherAdjustmentEnabled = true,
    this.isAutoBrightnessEnabled = true,
  }) : curvesMap = curvesMap ?? PresetConstants.getAllDefaults();

  List<FlSpot> get curvePoints => curvesMap[activePreset]!;

  Map<String, dynamic> toJson() => {
    'activePreset': activePreset.toJson(),
    'curvesMap': curvesMap.map(
      (key, value) =>
          MapEntry(key.name, value.map((p) => {'x': p.x, 'y': p.y}).toList()),
    ),
    'curveSharpness': curveSharpness,
    'isAutorunEnabled': isAutorunEnabled,
    'isWeatherAdjustmentEnabled': isWeatherAdjustmentEnabled,
    'isAutoBrightnessEnabled': isAutoBrightnessEnabled,
  };

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    final activePreset = json.containsKey('activePreset')
        ? PresetType.fromJson(json['activePreset'] as String)
        : PresetType.bright;

    Map<PresetType, List<FlSpot>>? curvesMap;
    if (json.containsKey('curvesMap')) {
      final mapData = json['curvesMap'] as Map<String, dynamic>;
      curvesMap = {};
      for (final type in PresetType.values) {
        if (mapData.containsKey(type.name)) {
          final pointsJson = mapData[type.name] as List<dynamic>;
          curvesMap[type] = pointsJson.map((p) {
            final map = p as Map<String, dynamic>;
            return FlSpot(
              (map['x'] as num).toDouble(),
              (map['y'] as num).toDouble(),
            );
          }).toList();
        } else {
          curvesMap[type] = PresetConstants.getDefaultPoints(type);
        }
      }
    } else if (json.containsKey('curvePoints')) {
      // Migration from old format
      final List<dynamic>? pointsJson = json['curvePoints'] as List<dynamic>?;
      final points = pointsJson?.map((p) {
        final map = p as Map<String, dynamic>;
        return FlSpot(
          (map['x'] as num).toDouble(),
          (map['y'] as num).toDouble(),
        );
      }).toList();

      curvesMap = PresetConstants.getAllDefaults();
      if (points != null) {
        curvesMap[PresetType.bright] = points;
      }
    }

    return SettingsState(
      activePreset: activePreset,
      curvesMap: curvesMap,
      curveSharpness: (json['curveSharpness'] as num?)?.toDouble() ?? 1.0,
      isAutorunEnabled: json['isAutorunEnabled'] as bool? ?? false,
      isWeatherAdjustmentEnabled:
          json['isWeatherAdjustmentEnabled'] as bool? ?? true,
      isAutoBrightnessEnabled: json['isAutoBrightnessEnabled'] as bool? ?? true,
    );
  }

  SettingsState copyWith({
    PresetType? activePreset,
    Map<PresetType, List<FlSpot>>? curvesMap,
    double? curveSharpness,
    bool? isAutorunEnabled,
    bool? isWeatherAdjustmentEnabled,
    bool? isAutoBrightnessEnabled,
  }) {
    return SettingsState(
      activePreset: activePreset ?? this.activePreset,
      curvesMap: curvesMap ?? this.curvesMap,
      curveSharpness: curveSharpness ?? this.curveSharpness,
      isAutorunEnabled: isAutorunEnabled ?? this.isAutorunEnabled,
      isWeatherAdjustmentEnabled:
          isWeatherAdjustmentEnabled ?? this.isWeatherAdjustmentEnabled,
      isAutoBrightnessEnabled:
          isAutoBrightnessEnabled ?? this.isAutoBrightnessEnabled,
    );
  }
}
