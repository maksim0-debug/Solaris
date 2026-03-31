import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/preset_type.dart';

class SettingsState {
  final PresetType activePreset;
  final Map<PresetType, List<FlSpot>> curvesMap;
  final double curveSharpness;
  final bool isAutorunEnabled;
  final bool isWeatherAdjustmentEnabled;
  final bool isAutoBrightnessEnabled;
  final bool isSmartCircadianEnabled;
  final bool isSleepDebtEnabled;
  final bool isSleepPressureEnabled;
  final bool isTimeShiftEnabled;
  final bool isWindDownEnabled;
  final bool isWindDownMasterEnabled;
  final bool isTimeShiftMasterEnabled;
  final bool isSleepPressureMasterEnabled;
  final bool isSleepDebtMasterEnabled;
  final double windDownBrightnessIntensity;
  final double windDownTemperatureIntensity;
  final double timeShiftIntensity;
  final double sleepPressureBrightnessIntensity;
  final double sleepDebtBrightnessIntensity;
  final double sleepDebtTemperatureIntensity;

  SettingsState({
    this.activePreset = PresetType.bright,
    Map<PresetType, List<FlSpot>>? curvesMap,
    this.curveSharpness = 1.0,
    this.isAutorunEnabled = false,
    this.isWeatherAdjustmentEnabled = true,
    this.isAutoBrightnessEnabled = true,
    this.isSmartCircadianEnabled = false,
    this.isSleepDebtEnabled = false,
    this.isSleepPressureEnabled = false,
    this.isTimeShiftEnabled = false,
    this.isWindDownEnabled = false,
    this.isWindDownMasterEnabled = false,
    this.isTimeShiftMasterEnabled = false,
    this.isSleepPressureMasterEnabled = false,
    this.isSleepDebtMasterEnabled = false,
    this.windDownBrightnessIntensity = 1.0,
    this.windDownTemperatureIntensity = 1.0,
    this.timeShiftIntensity = 1.0,
    this.sleepPressureBrightnessIntensity = 1.0,
    this.sleepDebtBrightnessIntensity = 1.0,
    this.sleepDebtTemperatureIntensity = 1.0,
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
    'isSmartCircadianEnabled': isSmartCircadianEnabled,
    'isSleepDebtEnabled': isSleepDebtEnabled,
    'isSleepPressureEnabled': isSleepPressureEnabled,
    'isTimeShiftEnabled': isTimeShiftEnabled,
    'isWindDownEnabled': isWindDownEnabled,
    'isWindDownMasterEnabled': isWindDownMasterEnabled,
    'isTimeShiftMasterEnabled': isTimeShiftMasterEnabled,
    'isSleepPressureMasterEnabled': isSleepPressureMasterEnabled,
    'isSleepDebtMasterEnabled': isSleepDebtMasterEnabled,
    'windDownBrightnessIntensity': windDownBrightnessIntensity,
    'windDownTemperatureIntensity': windDownTemperatureIntensity,
    'timeShiftIntensity': timeShiftIntensity,
    'sleepPressureBrightnessIntensity': sleepPressureBrightnessIntensity,
    'sleepDebtBrightnessIntensity': sleepDebtBrightnessIntensity,
    'sleepDebtTemperatureIntensity': sleepDebtTemperatureIntensity,
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
      isSmartCircadianEnabled: json['isSmartCircadianEnabled'] as bool? ?? false,
      isSleepDebtEnabled: json['isSleepDebtEnabled'] as bool? ?? true,
      isSleepPressureEnabled: json['isSleepPressureEnabled'] as bool? ?? true,
      isTimeShiftEnabled: json['isTimeShiftEnabled'] as bool? ?? true,
      isWindDownEnabled: json['isWindDownEnabled'] as bool? ?? true,
      isWindDownMasterEnabled: json['isWindDownMasterEnabled'] as bool? ?? true,
      isTimeShiftMasterEnabled: json['isTimeShiftMasterEnabled'] as bool? ?? true,
      isSleepPressureMasterEnabled: json['isSleepPressureMasterEnabled'] as bool? ?? true,
      isSleepDebtMasterEnabled: json['isSleepDebtMasterEnabled'] as bool? ?? true,
      windDownBrightnessIntensity: (json['windDownBrightnessIntensity'] as num?)?.toDouble() ?? 1.0,
      windDownTemperatureIntensity: (json['windDownTemperatureIntensity'] as num?)?.toDouble() ?? 1.0,
      timeShiftIntensity: (json['timeShiftIntensity'] as num?)?.toDouble() ?? 1.0,
      sleepPressureBrightnessIntensity: (json['sleepPressureBrightnessIntensity'] as num?)?.toDouble() ?? 1.0,
      sleepDebtBrightnessIntensity: (json['sleepDebtBrightnessIntensity'] as num?)?.toDouble() ?? 1.0,
      sleepDebtTemperatureIntensity: (json['sleepDebtTemperatureIntensity'] as num?)?.toDouble() ?? 1.0,
    );
  }

  SettingsState copyWith({
    PresetType? activePreset,
    Map<PresetType, List<FlSpot>>? curvesMap,
    double? curveSharpness,
    bool? isAutorunEnabled,
    bool? isWeatherAdjustmentEnabled,
    bool? isAutoBrightnessEnabled,
    bool? isSmartCircadianEnabled,
    bool? isSleepDebtEnabled,
    bool? isSleepPressureEnabled,
    bool? isTimeShiftEnabled,
    bool? isWindDownEnabled,
    bool? isWindDownMasterEnabled,
    bool? isTimeShiftMasterEnabled,
    bool? isSleepPressureMasterEnabled,
    bool? isSleepDebtMasterEnabled,
    double? windDownBrightnessIntensity,
    double? windDownTemperatureIntensity,
    double? timeShiftIntensity,
    double? sleepPressureBrightnessIntensity,
    double? sleepDebtBrightnessIntensity,
    double? sleepDebtTemperatureIntensity,
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
      isSmartCircadianEnabled:
          isSmartCircadianEnabled ?? this.isSmartCircadianEnabled,
      isSleepDebtEnabled: isSleepDebtEnabled ?? this.isSleepDebtEnabled,
      isSleepPressureEnabled: isSleepPressureEnabled ?? this.isSleepPressureEnabled,
      isTimeShiftEnabled: isTimeShiftEnabled ?? this.isTimeShiftEnabled,
      isWindDownEnabled: isWindDownEnabled ?? this.isWindDownEnabled,
      isWindDownMasterEnabled: isWindDownMasterEnabled ?? this.isWindDownMasterEnabled,
      isTimeShiftMasterEnabled: isTimeShiftMasterEnabled ?? this.isTimeShiftMasterEnabled,
      isSleepPressureMasterEnabled: isSleepPressureMasterEnabled ?? this.isSleepPressureMasterEnabled,
      isSleepDebtMasterEnabled: isSleepDebtMasterEnabled ?? this.isSleepDebtMasterEnabled,
      windDownBrightnessIntensity: windDownBrightnessIntensity ?? this.windDownBrightnessIntensity,
      windDownTemperatureIntensity: windDownTemperatureIntensity ?? this.windDownTemperatureIntensity,
      timeShiftIntensity: timeShiftIntensity ?? this.timeShiftIntensity,
      sleepPressureBrightnessIntensity: sleepPressureBrightnessIntensity ?? this.sleepPressureBrightnessIntensity,
      sleepDebtBrightnessIntensity: sleepDebtBrightnessIntensity ?? this.sleepDebtBrightnessIntensity,
      sleepDebtTemperatureIntensity: sleepDebtTemperatureIntensity ?? this.sleepDebtTemperatureIntensity,
    );
  }
}
