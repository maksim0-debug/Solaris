import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/preset_type.dart';

class TemperatureState {
  final TemperaturePresetType activePreset;
  final Map<TemperaturePresetType, List<FlSpot>> curvesMap;
  final bool isEnabled;
  final bool isSmartCircadianEnabled;
  final bool isSleepDebtEnabled;
  final bool isSleepPressureEnabled;
  final bool isTimeShiftEnabled;
  final bool isWindDownEnabled;
  final List<UserPreset> userPresets;
  final String? activeUserPresetId;
  final List<String> presetOrder;

  TemperatureState({
    this.activePreset = TemperaturePresetType.cool,
    Map<TemperaturePresetType, List<FlSpot>>? curvesMap,
    this.isEnabled = false,
    this.isSmartCircadianEnabled = false,
    this.isSleepDebtEnabled = false,
    this.isSleepPressureEnabled = false,
    this.isTimeShiftEnabled = false,
    this.isWindDownEnabled = false,
    this.userPresets = const [],
    this.activeUserPresetId,
    List<String>? presetOrder,
  }) : curvesMap = curvesMap ?? PresetConstants.getAllTemperatureDefaults(),
       presetOrder = presetOrder ?? [
         ...TemperaturePresetType.values.map((e) => 'system:${e.name}'),
         ...userPresets.map((e) => 'user:${e.id}'),
       ];

  List<FlSpot> get curvePoints {
    if (activeUserPresetId != null) {
      try {
        final userPreset = userPresets.firstWhere(
          (p) => p.id == activeUserPresetId,
        );
        return userPreset.points;
      } catch (_) {
        if (userPresets.isNotEmpty) return userPresets.first.points;
      }
    }
    return curvesMap[activePreset]!;
  }

  TemperatureState copyWith({
    TemperaturePresetType? activePreset,
    Map<TemperaturePresetType, List<FlSpot>>? curvesMap,
    bool? isEnabled,
    bool? isSmartCircadianEnabled,
    bool? isSleepDebtEnabled,
    bool? isSleepPressureEnabled,
    bool? isTimeShiftEnabled,
    bool? isWindDownEnabled,
    List<UserPreset>? userPresets,
    String? activeUserPresetId,
    List<String>? presetOrder,
    bool clearActiveUserPresetId = false,
  }) {
    return TemperatureState(
      activePreset: activePreset ?? this.activePreset,
      curvesMap: curvesMap ?? this.curvesMap,
      isEnabled: isEnabled ?? this.isEnabled,
      isSmartCircadianEnabled:
          isSmartCircadianEnabled ?? this.isSmartCircadianEnabled,
      isSleepDebtEnabled: isSleepDebtEnabled ?? this.isSleepDebtEnabled,
      isSleepPressureEnabled:
          isSleepPressureEnabled ?? this.isSleepPressureEnabled,
      isTimeShiftEnabled: isTimeShiftEnabled ?? this.isTimeShiftEnabled,
      isWindDownEnabled: isWindDownEnabled ?? this.isWindDownEnabled,
      userPresets: userPresets ?? this.userPresets,
      activeUserPresetId:
          clearActiveUserPresetId ? null : (activeUserPresetId ?? this.activeUserPresetId),
      presetOrder: presetOrder ?? this.presetOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activePreset': activePreset.toJson(),
      'isEnabled': isEnabled,
      'isSmartCircadianEnabled': isSmartCircadianEnabled,
      'isSleepDebtEnabled': isSleepDebtEnabled,
      'isSleepPressureEnabled': isSleepPressureEnabled,
      'isTimeShiftEnabled': isTimeShiftEnabled,
      'isWindDownEnabled': isWindDownEnabled,
      'userPresets': userPresets.map((p) => p.toJson()).toList(),
      'activeUserPresetId': activeUserPresetId,
      'presetOrder': presetOrder,
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
      isSmartCircadianEnabled: json['isSmartCircadianEnabled'] == true,
      isSleepDebtEnabled: json['isSleepDebtEnabled'] as bool? ?? true,
      isSleepPressureEnabled: json['isSleepPressureEnabled'] as bool? ?? true,
      isTimeShiftEnabled: json['isTimeShiftEnabled'] as bool? ?? true,
      isWindDownEnabled: json['isWindDownEnabled'] as bool? ?? true,
      userPresets: (json['userPresets'] as List<dynamic>?)?.map(
            (p) => UserPreset.fromJson(p as Map<String, dynamic>),
          ).toList() ??
          [],
      activeUserPresetId: json['activeUserPresetId'] as String?,
      presetOrder: (json['presetOrder'] as List<dynamic>?)?.cast<String>(),
      curvesMap: parsedCurvesMap,
    );
  }
}
