import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/env/env.dart';


enum MapStyleMode {
  auto,
  day,
  night;

  String toJson() => name;
  factory MapStyleMode.fromJson(String json) => MapStyleMode.values.firstWhere(
    (e) => e.name == json,
    orElse: () => MapStyleMode.auto,
  );
}

enum WeatherProvider {
  auto,
  weatherApi,
  openMeteo;

  String toJson() => name;
  factory WeatherProvider.fromJson(String json) => WeatherProvider.values
      .firstWhere((e) => e.name == json, orElse: () => WeatherProvider.auto);
}

enum StartupMode {
  minimized,
  tray;

  String toJson() => name;
  factory StartupMode.fromJson(String json) => StartupMode.values.firstWhere(
    (e) => e.name == json,
    orElse: () => StartupMode.minimized,
  );
}

class SettingsState {
  final PresetType activePreset;
  final Map<PresetType, List<FlSpot>> curvesMap;
  final double curveSharpness;
  final bool isAutorunEnabled;
  final bool isWeatherAdjustmentEnabled;
  final bool isWeatherTemperatureAdjustmentEnabled;
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
  final double sleepPressureTemperatureIntensity;
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
  final MapStyleMode mapStyleMode;
  final double weatherAdjustmentIntensity;
  final WeatherProvider weatherProvider;
  final StartupMode startupMode;
  final bool isLocalIpcServerEnabled;
  final int localIpcServerPort;
  final String customWeatherApiKey;
  final String customMapboxToken;
  final String customGoogleClientId;
  final String customGoogleClientSecret;

  SettingsState({
    this.activePreset = PresetType.bright,
    Map<PresetType, List<FlSpot>>? curvesMap,
    this.curveSharpness = 1.0,
    this.isAutorunEnabled = true,
    this.isWeatherAdjustmentEnabled = true,
    this.isWeatherTemperatureAdjustmentEnabled = true,
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
    this.sleepPressureTemperatureIntensity = 1.0,
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
    this.mapStyleMode = MapStyleMode.auto,
    this.weatherAdjustmentIntensity = 0.45,
    this.weatherProvider = WeatherProvider.auto,
    this.startupMode = StartupMode.minimized,
    this.isLocalIpcServerEnabled = false,
    this.localIpcServerPort = 45321,
    this.customWeatherApiKey = "",
    this.customMapboxToken = "",
    this.customGoogleClientId = "",
    this.customGoogleClientSecret = "",
  }) : curvesMap = curvesMap ?? PresetConstants.getAllDefaults(),
       presetOrder =
           presetOrder ??
           [
             ...PresetType.values.map((e) => 'system:${e.name}'),
             ...userPresets.map((e) => 'user:${e.id}'),
           ];

  String get effectiveWeatherApiKey =>
      customWeatherApiKey.isNotEmpty ? customWeatherApiKey : Env.weatherApiKey;

  String get effectiveMapboxToken =>
      customMapboxToken.isNotEmpty ? customMapboxToken : Env.mapboxToken;

  String get effectiveGoogleClientId =>
      customGoogleClientId.isNotEmpty ? customGoogleClientId : Env.googleClientId;

  String get effectiveGoogleClientSecret =>
      customGoogleClientSecret.isNotEmpty ? customGoogleClientSecret : Env.googleClientSecret;

  bool get isWeatherKeyAvailable =>
      customWeatherApiKey.isNotEmpty || Env.isWeatherApiKeyValid;

  bool get isMapboxTokenAvailable =>
      customMapboxToken.isNotEmpty || Env.isMapboxTokenValid;

  bool get isGoogleFitKeysAvailable =>
      (customGoogleClientId.isNotEmpty && customGoogleClientSecret.isNotEmpty) ||
      Env.isGoogleFitKeysValid;

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
    'isWeatherTemperatureAdjustmentEnabled': isWeatherTemperatureAdjustmentEnabled,
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
    'sleepPressureTemperatureIntensity': sleepPressureTemperatureIntensity,
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
    'mapStyleMode': mapStyleMode.toJson(),
    'weatherAdjustmentIntensity': weatherAdjustmentIntensity,
    'weatherProvider': weatherProvider.toJson(),
    'startupMode': startupMode.toJson(),
    'isLocalIpcServerEnabled': isLocalIpcServerEnabled,
    'localIpcServerPort': localIpcServerPort,
    'customWeatherApiKey': KeyObfuscator.encrypt(customWeatherApiKey),
    'customMapboxToken': KeyObfuscator.encrypt(customMapboxToken),
    'customGoogleClientId': KeyObfuscator.encrypt(customGoogleClientId),
    'customGoogleClientSecret': KeyObfuscator.encrypt(customGoogleClientSecret),
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
      isAutorunEnabled: json['isAutorunEnabled'] as bool? ?? true,
      isWeatherAdjustmentEnabled:
          json['isWeatherAdjustmentEnabled'] as bool? ?? true,
      isWeatherTemperatureAdjustmentEnabled:
          json['isWeatherTemperatureAdjustmentEnabled'] as bool? ??
          json['isWeatherAdjustmentEnabled'] as bool? ??
          true,
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
      sleepPressureTemperatureIntensity:
          (json['sleepPressureTemperatureIntensity'] as num?)?.toDouble() ?? 1.0,
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
        return {...map, 'identifier': 'next_preset'};
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
        return {...map, 'identifier': 'prev_preset'};
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
      userPresets:
          (json['userPresets'] as List<dynamic>?)
              ?.map((p) => UserPreset.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      activeUserPresetId: json['activeUserPresetId'] as String?,
      presetOrder: (json['presetOrder'] as List<dynamic>?)?.cast<String>(),
      showRainAnimation: json['showRainAnimation'] as bool? ?? true,
      showSnowAnimation: json['showSnowAnimation'] as bool? ?? true,
      showThunderAnimation: json['showThunderAnimation'] as bool? ?? true,
      showCloudAnimation: json['showCloudAnimation'] as bool? ?? true,
      mapStyleMode: MapStyleMode.fromJson(
        json['mapStyleMode'] as String? ?? 'auto',
      ),
      weatherAdjustmentIntensity:
          (json['weatherAdjustmentIntensity'] as num?)?.toDouble() ?? 0.6,
      weatherProvider: WeatherProvider.fromJson(
        json['weatherProvider'] as String? ?? 'auto',
      ),
      startupMode: StartupMode.fromJson(
        json['startupMode'] as String? ?? 'minimized',
      ),
      isLocalIpcServerEnabled: json['isLocalIpcServerEnabled'] as bool? ?? false,
      localIpcServerPort: json['localIpcServerPort'] as int? ?? 45321,
      customWeatherApiKey: json.containsKey('customWeatherApiKey')
          ? KeyObfuscator.decrypt(json['customWeatherApiKey'] as String)
          : "",
      customMapboxToken: json.containsKey('customMapboxToken')
          ? KeyObfuscator.decrypt(json['customMapboxToken'] as String)
          : "",
      customGoogleClientId: json.containsKey('customGoogleClientId')
          ? KeyObfuscator.decrypt(json['customGoogleClientId'] as String)
          : "",
      customGoogleClientSecret: json.containsKey('customGoogleClientSecret')
          ? KeyObfuscator.decrypt(json['customGoogleClientSecret'] as String)
          : "",
    );
  }

  SettingsState copyWith({
    PresetType? activePreset,
    Map<PresetType, List<FlSpot>>? curvesMap,
    double? curveSharpness,
    bool? isAutorunEnabled,
    bool? isWeatherAdjustmentEnabled,
    bool? isWeatherTemperatureAdjustmentEnabled,
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
    double? sleepPressureTemperatureIntensity,
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
    MapStyleMode? mapStyleMode,
    double? weatherAdjustmentIntensity,
    WeatherProvider? weatherProvider,
    StartupMode? startupMode,
    bool? isLocalIpcServerEnabled,
    int? localIpcServerPort,
    String? customWeatherApiKey,
    String? customMapboxToken,
    String? customGoogleClientId,
    String? customGoogleClientSecret,
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
      isWeatherTemperatureAdjustmentEnabled:
          isWeatherTemperatureAdjustmentEnabled ?? this.isWeatherTemperatureAdjustmentEnabled,
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
      sleepPressureTemperatureIntensity:
          sleepPressureTemperatureIntensity ??
          this.sleepPressureTemperatureIntensity,
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
      activeUserPresetId: clearActiveUserPresetId
          ? null
          : (activeUserPresetId ?? this.activeUserPresetId),
      presetOrder: presetOrder ?? this.presetOrder,
      showRainAnimation: showRainAnimation ?? this.showRainAnimation,
      showSnowAnimation: showSnowAnimation ?? this.showSnowAnimation,
      showThunderAnimation: showThunderAnimation ?? this.showThunderAnimation,
      showCloudAnimation: showCloudAnimation ?? this.showCloudAnimation,
      mapStyleMode: mapStyleMode ?? this.mapStyleMode,
      weatherAdjustmentIntensity:
          weatherAdjustmentIntensity ?? this.weatherAdjustmentIntensity,
      weatherProvider: weatherProvider ?? this.weatherProvider,
      startupMode: startupMode ?? this.startupMode,
      isLocalIpcServerEnabled:
          isLocalIpcServerEnabled ?? this.isLocalIpcServerEnabled,
      localIpcServerPort: localIpcServerPort ?? this.localIpcServerPort,
      customWeatherApiKey: customWeatherApiKey ?? this.customWeatherApiKey,
      customMapboxToken: customMapboxToken ?? this.customMapboxToken,
      customGoogleClientId: customGoogleClientId ?? this.customGoogleClientId,
      customGoogleClientSecret: customGoogleClientSecret ?? this.customGoogleClientSecret,
    );
  }
}

class DpapiPasswordChangedException implements Exception {
  final String message;
  DpapiPasswordChangedException(this.message);
  @override
  String toString() => "DpapiPasswordChangedException: $message";
}

class DpapiInvalidDataException implements Exception {
  final String message;
  DpapiInvalidDataException(this.message);
  @override
  String toString() => "DpapiInvalidDataException: $message";
}

class DpapiGenericException implements Exception {
  final String message;
  DpapiGenericException(this.message);
  @override
  String toString() => "DpapiGenericException: $message";
}

final class DATA_BLOB extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

abstract class _DpapiBindings {
  static final _crypt32 = Platform.isWindows ? DynamicLibrary.open('crypt32.dll') : null;
  static final _kernel32 = Platform.isWindows ? DynamicLibrary.open('kernel32.dll') : null;

  static final cryptProtectData = _crypt32?.lookupFunction<
      Int32 Function(
        Pointer<DATA_BLOB> pDataIn,
        Pointer<Utf16> szDataDescr,
        Pointer<DATA_BLOB> pOptionalEntropy,
        Pointer<Void> pvReserved,
        Pointer<Void> pPromptStruct,
        Uint32 dwFlags,
        Pointer<DATA_BLOB> pDataOut,
      ),
      int Function(
        Pointer<DATA_BLOB> pDataIn,
        Pointer<Utf16> szDataDescr,
        Pointer<DATA_BLOB> pOptionalEntropy,
        Pointer<Void> pvReserved,
        Pointer<Void> pPromptStruct,
        int dwFlags,
        Pointer<DATA_BLOB> pDataOut,
      )>('CryptProtectData');

  static final cryptUnprotectData = _crypt32?.lookupFunction<
      Int32 Function(
        Pointer<DATA_BLOB> pDataIn,
        Pointer<Pointer<Utf16>> ppszDataDescr,
        Pointer<DATA_BLOB> pOptionalEntropy,
        Pointer<Void> pvReserved,
        Pointer<Void> pPromptStruct,
        Uint32 dwFlags,
        Pointer<DATA_BLOB> pDataOut,
      ),
      int Function(
        Pointer<DATA_BLOB> pDataIn,
        Pointer<Pointer<Utf16>> ppszDataDescr,
        Pointer<DATA_BLOB> pOptionalEntropy,
        Pointer<Void> pvReserved,
        Pointer<Void> pPromptStruct,
        int dwFlags,
        Pointer<DATA_BLOB> pDataOut,
      )>('CryptUnprotectData');

  static final localFree = _kernel32?.lookupFunction<
      Pointer<Void> Function(IntPtr hMem),
      Pointer<Void> Function(int hMem)>('LocalFree');
}

class KeyObfuscator {
  static const int _xorKey = 0x3F;
  static const String _oldPrefix = "obf:";
  static const String _dpapiPrefix = "dpapi:";
  static const int _cryptProtectUiForbidden = 0x1;

  static String encrypt(String value) {
    if (value.isEmpty) return "";
    
    // Fallback for non-Windows platforms (e.g. testing or potential porting)
    if (!Platform.isWindows) {
      final bytes = utf8.encode(value);
      final encryptedBytes = bytes.map((b) => b ^ _xorKey).toList();
      return _oldPrefix + base64Url.encode(encryptedBytes);
    }

    final utf8Bytes = utf8.encode(value);
    
    Pointer<Uint8> inputPointer = nullptr;
    Pointer<DATA_BLOB> dataIn = nullptr;
    Pointer<DATA_BLOB> dataOut = nullptr;
    Pointer<Uint8> entropyPointer = nullptr;
    Pointer<DATA_BLOB> entropyBlob = nullptr;
    
    final inputLength = utf8Bytes.length;
    int entropyLength = 0;

    try {
      inputPointer = calloc<Uint8>(inputLength);
      final inputList = inputPointer.asTypedList(inputLength);
      inputList.setAll(0, utf8Bytes);

      dataIn = calloc<DATA_BLOB>();
      dataIn.ref.cbData = inputLength;
      dataIn.ref.pbData = inputPointer;

      dataOut = calloc<DATA_BLOB>();

      // Prepare entropy from env with fallback
      final entropyStr = Env.dpapiEntropy;
      final entropyBytes = utf8.encode(entropyStr.isNotEmpty ? entropyStr : 'SolarisDefaultEntropySaltKey321!');
      entropyLength = entropyBytes.length;
      
      entropyPointer = calloc<Uint8>(entropyLength);
      final entropyList = entropyPointer.asTypedList(entropyLength);
      entropyList.setAll(0, entropyBytes);

      entropyBlob = calloc<DATA_BLOB>();
      entropyBlob.ref.cbData = entropyLength;
      entropyBlob.ref.pbData = entropyPointer;

      final protectFn = _DpapiBindings.cryptProtectData;
      if (protectFn == null) {
        throw DpapiGenericException('CryptProtectData function is not available (crypt32.dll missing or corrupt)');
      }

      final result = protectFn(
        dataIn,
        nullptr,
        entropyBlob,
        nullptr,
        nullptr,
        _cryptProtectUiForbidden,
        dataOut,
      );

      if (result == 0) {
        throw DpapiGenericException('CryptProtectData failed: ${GetLastError()}');
      }

      final encryptedBytes = dataOut.ref.pbData.asTypedList(dataOut.ref.cbData);
      final encryptedList = Uint8List.fromList(encryptedBytes);
      
      return _dpapiPrefix + base64Url.encode(encryptedList);
    } finally {
      // Clear secrets from memory (Memory Remanence Fix)
      if (inputPointer != nullptr && inputLength > 0) {
        inputPointer.asTypedList(inputLength).fillRange(0, inputLength, 0);
      }
      if (dataOut != nullptr && dataOut.ref.pbData != nullptr && dataOut.ref.cbData > 0) {
        dataOut.ref.pbData.asTypedList(dataOut.ref.cbData).fillRange(0, dataOut.ref.cbData, 0);
        // Guaranteed release of memory allocated by Windows DPAPI (FFI memory leaks fix)
        final freeFn = _DpapiBindings.localFree;
        if (freeFn != null) {
          freeFn(dataOut.ref.pbData.address);
        }
      }
      if (entropyPointer != nullptr && entropyLength > 0) {
        entropyPointer.asTypedList(entropyLength).fillRange(0, entropyLength, 0);
      }

      // Free FFI structures
      if (inputPointer != nullptr) calloc.free(inputPointer);
      if (dataIn != nullptr) calloc.free(dataIn);
      if (dataOut != nullptr) calloc.free(dataOut);
      if (entropyPointer != nullptr) calloc.free(entropyPointer);
      if (entropyBlob != nullptr) calloc.free(entropyBlob);
    }
  }

  static String decrypt(String value) {
    if (value.isEmpty) return "";
    
    // Support legacy XOR-obfuscation format for seamless migration
    if (value.startsWith(_oldPrefix)) {
      try {
        final rawBase64 = value.substring(_oldPrefix.length);
        final encryptedBytes = base64Url.decode(rawBase64);
        final decryptedBytes = encryptedBytes.map((b) => b ^ _xorKey).toList();
        return utf8.decode(decryptedBytes);
      } catch (_) {
        throw DpapiInvalidDataException('Failed to decrypt old XOR format');
      }
    }

    if (!value.startsWith(_dpapiPrefix)) {
      return value;
    }

    if (!Platform.isWindows) {
      throw DpapiGenericException('DPAPI is only supported on Windows');
    }

    Pointer<Uint8> inputPointer = nullptr;
    Pointer<DATA_BLOB> dataIn = nullptr;
    Pointer<DATA_BLOB> dataOut = nullptr;
    Pointer<Uint8> entropyPointer = nullptr;
    Pointer<DATA_BLOB> entropyBlob = nullptr;

    int inputLength = 0;
    int entropyLength = 0;

    try {
      final rawBase64 = value.substring(_dpapiPrefix.length);
      final encryptedBytes = base64Url.decode(rawBase64);
      inputLength = encryptedBytes.length;
      
      inputPointer = calloc<Uint8>(inputLength);
      final inputList = inputPointer.asTypedList(inputLength);
      inputList.setAll(0, encryptedBytes);

      dataIn = calloc<DATA_BLOB>();
      dataIn.ref.cbData = inputLength;
      dataIn.ref.pbData = inputPointer;

      dataOut = calloc<DATA_BLOB>();

      // Prepare entropy from env with fallback
      final entropyStr = Env.dpapiEntropy;
      final entropyBytes = utf8.encode(entropyStr.isNotEmpty ? entropyStr : 'SolarisDefaultEntropySaltKey321!');
      entropyLength = entropyBytes.length;
      
      entropyPointer = calloc<Uint8>(entropyLength);
      final entropyList = entropyPointer.asTypedList(entropyLength);
      entropyList.setAll(0, entropyBytes);

      entropyBlob = calloc<DATA_BLOB>();
      entropyBlob.ref.cbData = entropyLength;
      entropyBlob.ref.pbData = entropyPointer;

      final unprotectFn = _DpapiBindings.cryptUnprotectData;
      if (unprotectFn == null) {
        throw DpapiGenericException('CryptUnprotectData function is not available (crypt32.dll missing or corrupt)');
      }

      final result = unprotectFn(
        dataIn,
        nullptr,
        entropyBlob,
        nullptr,
        nullptr,
        _cryptProtectUiForbidden,
        dataOut,
      );

      if (result == 0) {
        final errorCode = GetLastError();
        final u32Code = errorCode & 0xFFFFFFFF;
        // NTE_BAD_KEYSET = 0x80090016
        // SEC_E_DECRYPT_FAILURE = 0x80090020
        // NTE_BAD_KEY_STATE = 0x8009000B (most common error when credentials change or password is reset)
        // NTE_FAIL = 0x8009000F
        if (u32Code == 0x80090016 || 
            u32Code == 0x80090020 || 
            u32Code == 0x8009000B || 
            u32Code == 0x8009000F) {
          throw DpapiPasswordChangedException('Windows password changed or credentials invalid: 0x${u32Code.toRadixString(16)}');
        }
        throw DpapiInvalidDataException('CryptUnprotectData failed (probably corrupted data or wrong entropy): 0x${u32Code.toRadixString(16)}');
      }

      final decryptedBytes = dataOut.ref.pbData.asTypedList(dataOut.ref.cbData);
      final resultString = utf8.decode(decryptedBytes);

      return resultString;
    } on DpapiPasswordChangedException {
      rethrow;
    } on DpapiInvalidDataException {
      rethrow;
    } on DpapiGenericException {
      rethrow;
    } catch (e) {
      throw DpapiInvalidDataException('Invalid DPAPI base64 data: $e');
    } finally {
      // Clear secrets from memory (Memory Remanence Fix)
      if (inputPointer != nullptr && inputLength > 0) {
        inputPointer.asTypedList(inputLength).fillRange(0, inputLength, 0);
      }
      if (dataOut != nullptr && dataOut.ref.pbData != nullptr && dataOut.ref.cbData > 0) {
        dataOut.ref.pbData.asTypedList(dataOut.ref.cbData).fillRange(0, dataOut.ref.cbData, 0);
        // Guaranteed release of memory allocated by Windows DPAPI (FFI memory leaks fix)
        final freeFn = _DpapiBindings.localFree;
        if (freeFn != null) {
          freeFn(dataOut.ref.pbData.address);
        }
      }
      if (entropyPointer != nullptr && entropyLength > 0) {
        entropyPointer.asTypedList(entropyLength).fillRange(0, entropyLength, 0);
      }

      // Free FFI structures
      if (inputPointer != nullptr) calloc.free(inputPointer);
      if (dataIn != nullptr) calloc.free(dataIn);
      if (dataOut != nullptr) calloc.free(dataOut);
      if (entropyPointer != nullptr) calloc.free(entropyPointer);
      if (entropyBlob != nullptr) calloc.free(entropyBlob);
    }
  }
}
