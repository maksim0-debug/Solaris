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
  final int windDownDurationMinutes;
  final int timeShiftDurationMinutes;
  final double sleepPressureWakeLimitHours;
  final int sleepDebtThresholdMinutes;
  final int sleepToleranceWindow;
  final int sleepMaxAnomalies;
  final int sleepMinRegimeLength;
  final int sleepAnchorSize;
  final int sleepMaxSpread;
  final bool isGameModeEnabled;
  final double gameModeBrightness;
  final List<String> gameModeWhitelist;
  final List<String> gameModeBlacklist;
  final Map<String, dynamic>? nextPresetHotKey;
  final Map<String, dynamic>? prevPresetHotKey;
  final Map<String, dynamic>? brightnessUpHotKey;
  final Map<String, dynamic>? brightnessDownHotKey;
  final Map<String, dynamic>? autoBrightnessHotKey;
  final double brightnessStepUp;
  final double brightnessStepDown;
  final bool isMultiMonitorOffsetEnabled;
  final double brightnessOffset;
  final List<UserPreset> userPresets;
  final String? activeUserPresetId;
  final List<String> presetOrder;
  final bool showRainAnimation;
  final bool showSnowAnimation;
  final bool showThunderAnimation;
  final bool showCloudAnimation;

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
    this.windDownDurationMinutes = 120,
    this.timeShiftDurationMinutes = 360,
    this.sleepPressureWakeLimitHours = 16.0,
    this.sleepDebtThresholdMinutes = 390,
    this.sleepToleranceWindow = 105,
    this.sleepMaxAnomalies = 2,
    this.sleepMinRegimeLength = 2,
    this.sleepAnchorSize = 2,
    this.sleepMaxSpread = 105,
    this.isGameModeEnabled = true,
    this.gameModeBrightness = 80.0,
    this.gameModeWhitelist = const [],
    this.gameModeBlacklist = const [
      'chrome.exe',
      'idea64.exe',
      'code.exe',
      'devenv.exe',
      'ShareX.exe',
    ],
    this.nextPresetHotKey = const {
      'keyCode': 'arrowLeft',
      'modifiers': ['control', 'shift'],
      'identifier': 'next_preset',
    },
    this.prevPresetHotKey = const {
      'keyCode': 'arrowRight',
      'modifiers': ['control', 'shift'],
      'identifier': 'prev_preset',
    },
    this.brightnessUpHotKey,
    this.brightnessDownHotKey,
    this.autoBrightnessHotKey,
    this.brightnessStepUp = 5.0,
    this.brightnessStepDown = 5.0,
    this.isMultiMonitorOffsetEnabled = false,
    this.brightnessOffset = 0.0,
    this.userPresets = const [],
     this.activeUserPresetId,
    List<String>? presetOrder,
    this.showRainAnimation = true,
    this.showSnowAnimation = true,
    this.showThunderAnimation = true,
    this.showCloudAnimation = true,
  }) : curvesMap = curvesMap ?? PresetConstants.getAllDefaults(),
       presetOrder = presetOrder ?? [
         ...PresetType.values.map((e) => 'system:${e.name}'),
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
    'windDownDurationMinutes': windDownDurationMinutes,
    'timeShiftDurationMinutes': timeShiftDurationMinutes,
    'sleepPressureWakeLimitHours': sleepPressureWakeLimitHours,
    'sleepDebtThresholdMinutes': sleepDebtThresholdMinutes,
    'sleepToleranceWindow': sleepToleranceWindow,
    'sleepMaxAnomalies': sleepMaxAnomalies,
    'sleepMinRegimeLength': sleepMinRegimeLength,
    'sleepAnchorSize': sleepAnchorSize,
    'sleepMaxSpread': sleepMaxSpread,
    'isGameModeEnabled': isGameModeEnabled,
    'gameModeBrightness': gameModeBrightness,
    'gameModeWhitelist': gameModeWhitelist,
    'gameModeBlacklist': gameModeBlacklist,
    'nextPresetHotKey': nextPresetHotKey,
    'prevPresetHotKey': prevPresetHotKey,
    'brightnessUpHotKey': brightnessUpHotKey,
    'brightnessDownHotKey': brightnessDownHotKey,
    'autoBrightnessHotKey': autoBrightnessHotKey,
    'brightnessStepUp': brightnessStepUp,
    'brightnessStepDown': brightnessStepDown,
    'isMultiMonitorOffsetEnabled': isMultiMonitorOffsetEnabled,
    'brightnessOffset': brightnessOffset,
    'userPresets': userPresets.map((p) => p.toJson()).toList(),
     'activeUserPresetId': activeUserPresetId,
    'presetOrder': presetOrder,
    'showRainAnimation': showRainAnimation,
    'showSnowAnimation': showSnowAnimation,
    'showThunderAnimation': showThunderAnimation,
    'showCloudAnimation': showCloudAnimation,
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
      isSmartCircadianEnabled:
          json['isSmartCircadianEnabled'] as bool? ?? false,
      isSleepDebtEnabled: json['isSleepDebtEnabled'] as bool? ?? true,
      isSleepPressureEnabled: json['isSleepPressureEnabled'] as bool? ?? true,
      isTimeShiftEnabled: json['isTimeShiftEnabled'] as bool? ?? true,
      isWindDownEnabled: json['isWindDownEnabled'] as bool? ?? true,
      isWindDownMasterEnabled: json['isWindDownMasterEnabled'] as bool? ?? true,
      isTimeShiftMasterEnabled:
          json['isTimeShiftMasterEnabled'] as bool? ?? true,
      isSleepPressureMasterEnabled:
          json['isSleepPressureMasterEnabled'] as bool? ?? true,
      isSleepDebtMasterEnabled:
          json['isSleepDebtMasterEnabled'] as bool? ?? true,
      windDownBrightnessIntensity:
          (json['windDownBrightnessIntensity'] as num?)?.toDouble() ?? 1.0,
      windDownTemperatureIntensity:
          (json['windDownTemperatureIntensity'] as num?)?.toDouble() ?? 1.0,
      timeShiftIntensity:
          (json['timeShiftIntensity'] as num?)?.toDouble() ?? 1.0,
      sleepPressureBrightnessIntensity:
          (json['sleepPressureBrightnessIntensity'] as num?)?.toDouble() ?? 1.0,
      sleepDebtBrightnessIntensity:
          (json['sleepDebtBrightnessIntensity'] as num?)?.toDouble() ?? 1.0,
      sleepDebtTemperatureIntensity:
          (json['sleepDebtTemperatureIntensity'] as num?)?.toDouble() ?? 1.0,
      windDownDurationMinutes: json['windDownDurationMinutes'] as int? ?? 120,
      timeShiftDurationMinutes: json['timeShiftDurationMinutes'] as int? ?? 360,
      sleepPressureWakeLimitHours:
          (json['sleepPressureWakeLimitHours'] as num?)?.toDouble() ?? 16.0,
      sleepDebtThresholdMinutes:
          json['sleepDebtThresholdMinutes'] as int? ?? 390,
      sleepToleranceWindow: json['sleepToleranceWindow'] as int? ?? 105,
      sleepMaxAnomalies: json['sleepMaxAnomalies'] as int? ?? 2,
      sleepMinRegimeLength: json['sleepMinRegimeLength'] as int? ?? 2,
      sleepAnchorSize: json['sleepAnchorSize'] as int? ?? 2,
      sleepMaxSpread: json['sleepMaxSpread'] as int? ?? 105,
      isGameModeEnabled: json['isGameModeEnabled'] as bool? ?? true,
      gameModeBrightness:
          (json['gameModeBrightness'] as num?)?.toDouble() ?? 80.0,
      gameModeWhitelist:
          (json['gameModeWhitelist'] as List<dynamic>?)?.cast<String>() ?? [],
      gameModeBlacklist:
          (json['gameModeBlacklist'] as List<dynamic>?)?.cast<String>() ??
          ['chrome.exe', 'idea64.exe', 'code.exe', 'devenv.exe', 'ShareX.exe'],
      nextPresetHotKey: (() {
        // Migration from brighterHotKey
        final keyName = json.containsKey('nextPresetHotKey')
            ? 'nextPresetHotKey'
            : 'brighterHotKey';
        if (!json.containsKey(keyName)) {
          return const {
            'keyCode': 'arrowLeft',
            'modifiers': ['control', 'shift'],
            'identifier': 'next_preset',
          };
        }
        if (json[keyName] == null) return null;
        final map = json[keyName] as Map<String, dynamic>;
        return {
          ...map,
          'identifier': 'next_preset',
        };
      })(),
      prevPresetHotKey: (() {
        // Migration from darkerHotKey
        final keyName = json.containsKey('prevPresetHotKey')
            ? 'prevPresetHotKey'
            : 'darkerHotKey';
        if (!json.containsKey(keyName)) {
          return const {
            'keyCode': 'arrowRight',
            'modifiers': ['control', 'shift'],
            'identifier': 'prev_preset',
          };
        }
        if (json[keyName] == null) return null;
        final map = json[keyName] as Map<String, dynamic>;
        return {
          ...map,
          'identifier': 'prev_preset',
        };
      })(),
      brightnessUpHotKey: json['brightnessUpHotKey'] as Map<String, dynamic>?,
      brightnessDownHotKey:
          json['brightnessDownHotKey'] as Map<String, dynamic>?,
      autoBrightnessHotKey:
          json['autoBrightnessHotKey'] as Map<String, dynamic>?,
      brightnessStepUp: (json['brightnessStepUp'] as num?)?.toDouble() ?? 5.0,
      brightnessStepDown:
          (json['brightnessStepDown'] as num?)?.toDouble() ?? 5.0,
      isMultiMonitorOffsetEnabled:
          json['isMultiMonitorOffsetEnabled'] as bool? ?? false,
      brightnessOffset: (json['brightnessOffset'] as num?)?.toDouble() ?? 0.0,
      userPresets: (json['userPresets'] as List<dynamic>?)?.map(
            (p) => UserPreset.fromJson(p as Map<String, dynamic>),
          ).toList() ??
          [],
       activeUserPresetId: json['activeUserPresetId'] as String?,
      presetOrder: (json['presetOrder'] as List<dynamic>?)?.cast<String>(),
      showRainAnimation: json['showRainAnimation'] as bool? ?? true,
      showSnowAnimation: json['showSnowAnimation'] as bool? ?? true,
      showThunderAnimation: json['showThunderAnimation'] as bool? ?? true,
      showCloudAnimation: json['showCloudAnimation'] as bool? ?? true,
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
    int? windDownDurationMinutes,
    int? timeShiftDurationMinutes,
    double? sleepPressureWakeLimitHours,
    int? sleepDebtThresholdMinutes,
    int? sleepToleranceWindow,
    int? sleepMaxAnomalies,
    int? sleepMinRegimeLength,
    int? sleepAnchorSize,
    int? sleepMaxSpread,
    bool? isGameModeEnabled,
    double? gameModeBrightness,
    List<String>? gameModeWhitelist,
    List<String>? gameModeBlacklist,
    Map<String, dynamic>? nextPresetHotKey,
    Map<String, dynamic>? prevPresetHotKey,
    Map<String, dynamic>? brightnessUpHotKey,
    Map<String, dynamic>? brightnessDownHotKey,
    Map<String, dynamic>? autoBrightnessHotKey,
    double? brightnessStepUp,
    double? brightnessStepDown,
    bool? isMultiMonitorOffsetEnabled,
    double? brightnessOffset,
    List<UserPreset>? userPresets,
     String? activeUserPresetId,
    List<String>? presetOrder,
    bool? showRainAnimation,
    bool? showSnowAnimation,
    bool? showThunderAnimation,
    bool? showCloudAnimation,
    bool clearNextPresetHotKey = false,
    bool clearPrevPresetHotKey = false,
    bool clearBrightnessUpHotKey = false,
    bool clearBrightnessDownHotKey = false,
    bool clearAutoBrightnessHotKey = false,
    bool clearActiveUserPresetId = false,
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
      isSleepPressureEnabled:
          isSleepPressureEnabled ?? this.isSleepPressureEnabled,
      isTimeShiftEnabled: isTimeShiftEnabled ?? this.isTimeShiftEnabled,
      isWindDownEnabled: isWindDownEnabled ?? this.isWindDownEnabled,
      isWindDownMasterEnabled:
          isWindDownMasterEnabled ?? this.isWindDownMasterEnabled,
      isTimeShiftMasterEnabled:
          isTimeShiftMasterEnabled ?? this.isTimeShiftMasterEnabled,
      isSleepPressureMasterEnabled:
          isSleepPressureMasterEnabled ?? this.isSleepPressureMasterEnabled,
      isSleepDebtMasterEnabled:
          isSleepDebtMasterEnabled ?? this.isSleepDebtMasterEnabled,
      windDownBrightnessIntensity:
          windDownBrightnessIntensity ?? this.windDownBrightnessIntensity,
      windDownTemperatureIntensity:
          windDownTemperatureIntensity ?? this.windDownTemperatureIntensity,
      timeShiftIntensity: timeShiftIntensity ?? this.timeShiftIntensity,
      sleepPressureBrightnessIntensity:
          sleepPressureBrightnessIntensity ??
          this.sleepPressureBrightnessIntensity,
      sleepDebtBrightnessIntensity:
          sleepDebtBrightnessIntensity ?? this.sleepDebtBrightnessIntensity,
      sleepDebtTemperatureIntensity:
          sleepDebtTemperatureIntensity ?? this.sleepDebtTemperatureIntensity,
      windDownDurationMinutes:
          windDownDurationMinutes ?? this.windDownDurationMinutes,
      timeShiftDurationMinutes:
          timeShiftDurationMinutes ?? this.timeShiftDurationMinutes,
      sleepPressureWakeLimitHours:
          sleepPressureWakeLimitHours ?? this.sleepPressureWakeLimitHours,
      sleepDebtThresholdMinutes:
          sleepDebtThresholdMinutes ?? this.sleepDebtThresholdMinutes,
      sleepToleranceWindow: sleepToleranceWindow ?? this.sleepToleranceWindow,
      sleepMaxAnomalies: sleepMaxAnomalies ?? this.sleepMaxAnomalies,
      sleepMinRegimeLength: sleepMinRegimeLength ?? this.sleepMinRegimeLength,
      sleepAnchorSize: sleepAnchorSize ?? this.sleepAnchorSize,
      sleepMaxSpread: sleepMaxSpread ?? this.sleepMaxSpread,
      isGameModeEnabled: isGameModeEnabled ?? this.isGameModeEnabled,
      gameModeBrightness: gameModeBrightness ?? this.gameModeBrightness,
      gameModeWhitelist: gameModeWhitelist ?? this.gameModeWhitelist,
      gameModeBlacklist: gameModeBlacklist ?? this.gameModeBlacklist,
      nextPresetHotKey: clearNextPresetHotKey
          ? null
          : (nextPresetHotKey ?? this.nextPresetHotKey),
      prevPresetHotKey: clearPrevPresetHotKey
          ? null
          : (prevPresetHotKey ?? this.prevPresetHotKey),
      brightnessUpHotKey: clearBrightnessUpHotKey
          ? null
          : (brightnessUpHotKey ?? this.brightnessUpHotKey),
      brightnessDownHotKey: clearBrightnessDownHotKey
          ? null
          : (brightnessDownHotKey ?? this.brightnessDownHotKey),
      autoBrightnessHotKey: clearAutoBrightnessHotKey
          ? null
          : (autoBrightnessHotKey ?? this.autoBrightnessHotKey),
      brightnessStepUp: brightnessStepUp ?? this.brightnessStepUp,
      brightnessStepDown: brightnessStepDown ?? this.brightnessStepDown,
      isMultiMonitorOffsetEnabled:
          isMultiMonitorOffsetEnabled ?? this.isMultiMonitorOffsetEnabled,
      brightnessOffset: brightnessOffset ?? this.brightnessOffset,
      userPresets: userPresets ?? this.userPresets,
       activeUserPresetId:
          clearActiveUserPresetId ? null : (activeUserPresetId ?? this.activeUserPresetId),
      presetOrder: presetOrder ?? this.presetOrder,
      showRainAnimation: showRainAnimation ?? this.showRainAnimation,
      showSnowAnimation: showSnowAnimation ?? this.showSnowAnimation,
      showThunderAnimation: showThunderAnimation ?? this.showThunderAnimation,
      showCloudAnimation: showCloudAnimation ?? this.showCloudAnimation,
    );
  }
}
