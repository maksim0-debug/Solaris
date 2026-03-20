import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/services/location_service.dart';
import 'package:solaris/services/solar_service.dart';
import 'package:solaris/services/time_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/services/sun_calculator_service.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/services/autorun_service.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:solaris/models/location_settings.dart' as model;

final locationServiceProvider = Provider((ref) => LocationService());
final solarServiceProvider = Provider(
  (ref) => SolarService(),
); // Keep for now or remove if unused elsewhere
final sunCalculatorServiceProvider = Provider((ref) => SunCalculatorService());
final timeServiceProvider = Provider((ref) => TimeService());
final monitorServiceProvider = Provider((ref) => MonitorService());
final circadianServiceProvider = Provider((ref) => CircadianService());
final brightnessServiceProvider = Provider((ref) => BrightnessService());
final storageServiceProvider = Provider((ref) => StorageService());

// Провайдер для SharedPreferences (переопределяется в main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

// 1. Провайдер самого сервиса
final weatherServiceProvider = Provider((ref) => WeatherService());

// 2. Асинхронный провайдер данных о погоде
final currentWeatherProvider = FutureProvider<WeatherData?>((ref) async {
  final locationAsync = ref.watch(effectiveLocationProvider);
  final weatherService = ref.watch(weatherServiceProvider);

  // Ждем, пока появится локация
  final pos = locationAsync.value;
  if (pos == null) return null;

  // Настраиваем автообновление каждые 15 минут (900 секунд)
  final timer = Timer(const Duration(minutes: 15), () {
    ref.invalidateSelf(); // Заставляет провайдер обновить данные
  });

  // Очищаем таймер, если провайдер уничтожается
  ref.onDispose(() => timer.cancel());

  // Делаем запрос к API
  return await weatherService.fetchCurrentWeather(pos.latitude, pos.longitude);
});

/// Data class representing the current solar state for the UI.
class SolarState {
  final SolarPhaseModel phases;
  final CurrentDayPhase currentPhase;
  final Duration timeUntilNextEvent;
  final double sunElevation;
  final double sunAzimuth;
  final double sunZenith;
  final double sunProgress;
  final double uvIndex;
  final double spectralIntensity;
  final String azimuthTrend;
  final String elevationTrend;

  SolarState({
    required this.phases,
    required this.currentPhase,
    required this.timeUntilNextEvent,
    required this.sunElevation,
    required this.sunAzimuth,
    required this.sunZenith,
    required this.sunProgress,
    required this.uvIndex,
    required this.spectralIntensity,
    required this.azimuthTrend,
    required this.elevationTrend,
  });
}

final locationStreamProvider = StreamProvider<Position>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.getLocationStream();
});

class LocationSettingsNotifier extends AsyncNotifier<model.LocationSettings> {
  static const _filename = 'location_settings.json';

  @override
  Future<model.LocationSettings> build() async {
    final storage = ref.watch(storageServiceProvider);
    final jsonStr = await storage.load(_filename);
    if (jsonStr != null) {
      try {
        return model.LocationSettings.fromJson(
          jsonDecode(jsonStr) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('Error parsing location settings: $e');
      }
    }
    return const model.LocationSettings();
  }

  Future<void> updateSettings(model.LocationSettings settings) async {
    state = AsyncData(settings);
    final storage = ref.read(storageServiceProvider);
    await storage.save(_filename, jsonEncode(settings.toJson()));
  }

  Future<void> setManualLocation(double lat, double lon) async {
    final current = state.value ?? const model.LocationSettings();
    await updateSettings(
      current.copyWith(
        useManual: true,
        manualLatitude: lat,
        manualLongitude: lon,
      ),
    );
  }

  Future<void> setAutoLocation() async {
    final current = state.value ?? const model.LocationSettings();
    await updateSettings(current.copyWith(useManual: false));
  }
}

final locationSettingsProvider =
    AsyncNotifierProvider<LocationSettingsNotifier, model.LocationSettings>(
      LocationSettingsNotifier.new,
    );

final effectiveLocationProvider = Provider<AsyncValue<Position>>((ref) {
  final settingsAsync = ref.watch(locationSettingsProvider);
  final streamAsync = ref.watch(locationStreamProvider);

  return settingsAsync.when(
    data: (settings) {
      if (settings.useManual &&
          settings.manualLatitude != null &&
          settings.manualLongitude != null) {
        return AsyncData(
          Position(
            latitude: settings.manualLatitude!,
            longitude: settings.manualLongitude!,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          ),
        );
      }
      return streamAsync;
    },
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
  );
});

final currentTimeProvider = StreamProvider<DateTime>((ref) {
  final service = ref.watch(timeServiceProvider);
  return service.getTimeStream();
});

/// Provider that emits the current solar state every second.
final solarStateStreamProvider = StreamProvider<SolarState>((ref) async* {
  final service = ref.watch(sunCalculatorServiceProvider);
  final locationAsync = ref.watch(effectiveLocationProvider);

  // Use location from provider, or default to Kyiv if loading
  final pos = locationAsync.value;
  final lat = pos?.latitude ?? 50.45;
  final lon = pos?.longitude ?? 30.52;

  // Initial calculation
  SolarPhaseModel phases = await service.calculatePhases(lat, lon);

  // Current day tracker to trigger daily recalculation at midnight
  int currentDay = DateTime.now().day;

  // Previous values for trend calculation
  double? prevAzimuth;
  double? prevElevation;

  while (true) {
    final now = DateTime.now();

    // Check for day change
    if (now.day != currentDay) {
      phases = await service.calculatePhases(lat, lon, now);
      currentDay = now.day;
    }

    final currentElevation = service.getSunElevation(lat, lon, now);
    final currentAzimuth = service.getSunAzimuth(lat, lon, now);

    String azTrend = "constant";
    if (prevAzimuth != null) {
      final diff = currentAzimuth - prevAzimuth;
      if (diff > 0.001) azTrend = "+${diff.toStringAsFixed(2)}";
      if (diff < -0.001) azTrend = diff.toStringAsFixed(2);
    }

    String elTrend = "constant";
    if (prevElevation != null) {
      final diff = currentElevation - prevElevation;
      if (diff > 0.001) elTrend = "+${diff.toStringAsFixed(2)}";
      if (diff < -0.001) elTrend = diff.toStringAsFixed(2);
    }

    yield SolarState(
      phases: phases,
      currentPhase: service.getCurrentPhase(phases, now),
      timeUntilNextEvent: service.getTimeUntilNextEvent(phases, now),
      sunElevation: currentElevation,
      sunAzimuth: currentAzimuth,
      sunZenith: service.getSunZenith(lat, lon, now),
      sunProgress: service.getSunProgress(phases, now),
      uvIndex: service.getUVIndex(currentElevation),
      spectralIntensity: service.getSpectralIntensity(currentElevation),
      azimuthTrend: azTrend,
      elevationTrend: elTrend,
    );

    prevAzimuth = currentAzimuth;
    prevElevation = currentElevation;

    await Future<void>.delayed(const Duration(seconds: 1));
  }
});

// Deprecated: use solarStateStreamProvider instead
final solarDataProvider = Provider<AsyncValue<SolarData>>((ref) {
  // Keeping it for backward compatibility if needed, but everything should migrate
  return const AsyncValue.loading();
});

class MonitorListNotifier extends AsyncNotifier<List<MonitorInfo>> {
  @override
  Future<List<MonitorInfo>> build() async {
    return ref.watch(monitorServiceProvider).getConnectedMonitors();
  }

  void updateBrightness(String deviceName, int brightness) {
    state.whenData((monitors) {
      state = AsyncData(
        monitors.map((m) {
          if (m.deviceName == deviceName) {
            return MonitorInfo(
              name: m.name,
              friendlyName: m.friendlyName,
              deviceName: m.deviceName,
              isPrimary: m.isPrimary,
              realBrightness: brightness,
            );
          }
          return m;
        }).toList(),
      );
    });
  }
}

final monitorListProvider =
    AsyncNotifierProvider<MonitorListNotifier, List<MonitorInfo>>(
      MonitorListNotifier.new,
    );

/// Provider for the currently selected monitor(s).
/// Default is 'all'. Otherwise, it's the [deviceName] of a specific monitor.
class SelectedMonitorIdNotifier extends Notifier<String> {
  @override
  String build() => 'all';
  void select(String id) => state = id;
}

final selectedMonitorIdProvider =
    NotifierProvider<SelectedMonitorIdNotifier, String>(
      SelectedMonitorIdNotifier.new,
    );

/// Provider for the monitor currently being edited in the Settings tab.
/// Default is 'all'.
class SettingsMonitorIdNotifier extends Notifier<String> {
  @override
  String build() => 'all';
  void select(String id) => state = id;
}

final settingsMonitorIdProvider =
    NotifierProvider<SettingsMonitorIdNotifier, String>(
      SettingsMonitorIdNotifier.new,
    );

enum AppScreen { dashboard, schedule, settings, location }

class ActiveScreenNotifier extends Notifier<AppScreen> {
  @override
  AppScreen build() => AppScreen.dashboard;
  void setScreen(AppScreen screen) => state = screen;
}

final activeScreenProvider = NotifierProvider<ActiveScreenNotifier, AppScreen>(
  ActiveScreenNotifier.new,
);

class AutoAdjustmentNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final autoAdjustmentProvider = NotifierProvider<AutoAdjustmentNotifier, bool>(
  AutoAdjustmentNotifier.new,
);

class ManualBrightnessNotifier extends Notifier<double> {
  @override
  double build() => 100.0;
  void update(double value) => state = value;
}

final manualBrightnessProvider =
    NotifierProvider<ManualBrightnessNotifier, double>(
      ManualBrightnessNotifier.new,
    );

class SettingsState {
  final double curveSharpness;
  final List<FlSpot> curvePoints;
  final bool isAutorunEnabled;

  SettingsState({
    this.curveSharpness = 1.0,
    this.isAutorunEnabled = false,
    List<FlSpot>? curvePoints,
  }) : curvePoints = curvePoints ?? _defaultPoints();

  static List<FlSpot> _defaultPoints() => const [
    FlSpot(-20, 15),
    FlSpot(-6, 25),
    FlSpot(0, 60),
    FlSpot(10, 85),
    FlSpot(30, 100),
    FlSpot(90, 100),
  ];

  Map<String, dynamic> toJson() => {
    'curveSharpness': curveSharpness,
    'isAutorunEnabled': isAutorunEnabled,
    'curvePoints': curvePoints.map((p) => {'x': p.x, 'y': p.y}).toList(),
  };

  factory SettingsState.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? pointsJson = json['curvePoints'] as List<dynamic>?;
    final points = pointsJson?.map((p) {
      final map = p as Map<String, dynamic>;
      return FlSpot((map['x'] as num).toDouble(), (map['y'] as num).toDouble());
    }).toList();

    return SettingsState(
      curveSharpness: (json['curveSharpness'] as num?)?.toDouble() ?? 1.0,
      isAutorunEnabled: json['isAutorunEnabled'] as bool? ?? false,
      curvePoints: points,
    );
  }

  SettingsState copyWith({
    double? curveSharpness,
    List<FlSpot>? curvePoints,
    bool? isAutorunEnabled,
  }) {
    return SettingsState(
      curveSharpness: curveSharpness ?? this.curveSharpness,
      curvePoints: curvePoints ?? this.curvePoints,
      isAutorunEnabled: isAutorunEnabled ?? this.isAutorunEnabled,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<Map<String, SettingsState>> {
  static const _settingsFilename = 'monitor_settings.json';

  @override
  Future<Map<String, SettingsState>> build() async {
    final storage = ref.watch(storageServiceProvider);
    return await _loadSettings(storage);
  }

  Future<Map<String, SettingsState>> _loadSettings(
    StorageService storage,
  ) async {
    final String? jsonStr = await storage.load(_settingsFilename);
    final Map<String, SettingsState> map = {'all': SettingsState()};

    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          map[key] = SettingsState.fromJson(value as Map<String, dynamic>);
        });
      } catch (e) {
        debugPrint('Error loading settings from file: $e');
      }
    }
    return map;
  }

  Future<void> _saveSettings() async {
    state.whenData((currentMap) async {
      final storage = ref.read(storageServiceProvider);
      final encoded = currentMap.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
      await storage.save(_settingsFilename, jsonEncode(encoded));
    });
  }

  SettingsState _getSettings(String? monitorId) {
    final Map<String, SettingsState> currentMap =
        state.value ?? {'all': SettingsState()};
    final String id = (monitorId ?? ref.read(settingsMonitorIdProvider))
        .toString();
    return currentMap[id] ?? currentMap['all']!;
  }

  Future<void> _updateSettings(
    String? monitorId,
    SettingsState newState,
  ) async {
    final currentMap = state.value ?? {'all': SettingsState()};
    final String id = (monitorId ?? ref.read(settingsMonitorIdProvider))
        .toString();
    final newStateMap = Map<String, SettingsState>.from(currentMap)
      ..[id] = newState;

    if (id == 'all') {
      for (final key in newStateMap.keys.toList()) {
        if (key != 'all') {
          newStateMap[key] = newState;
        }
      }
    }

    state = AsyncData(newStateMap);
    await _saveSettings();
  }

  void updateCurveSharpness(double value, {String? monitorId}) {
    final current = _getSettings(monitorId);
    _updateSettings(monitorId, current.copyWith(curveSharpness: value));
  }

  void updateAutorun(bool enabled) {
    final currentMap = state.value ?? {'all': SettingsState()};
    final current = currentMap['all']!;
    _updateSettings('all', current.copyWith(isAutorunEnabled: enabled));
    AutorunService.setEnabled(enabled);
  }

  void updateCurvePoints(List<FlSpot> points, {String? monitorId}) {
    final sortedPoints = List<FlSpot>.from(points)
      ..sort((a, b) => a.x.compareTo(b.x));

    if (sortedPoints.isEmpty || sortedPoints.first.x > -20) {
      sortedPoints.insert(
        0,
        FlSpot(-20, sortedPoints.isEmpty ? 15 : sortedPoints.first.y),
      );
    }
    if (sortedPoints.last.x < 90) {
      sortedPoints.add(FlSpot(90, sortedPoints.last.y));
    }

    final current = _getSettings(monitorId);
    _updateSettings(monitorId, current.copyWith(curvePoints: sortedPoints));
  }

  void addCurvePoint(FlSpot point, {String? monitorId}) {
    final current = _getSettings(monitorId);
    final newPoints = List<FlSpot>.from(current.curvePoints)..add(point);
    updateCurvePoints(newPoints, monitorId: monitorId);
  }

  void removeCurvePoint(int index, {String? monitorId}) {
    final current = _getSettings(monitorId);
    if (index >= 0 && index < current.curvePoints.length) {
      if (current.curvePoints[index].x == -20 ||
          current.curvePoints[index].x == 90)
        return;
      final newPoints = List<FlSpot>.from(current.curvePoints)..removeAt(index);
      updateCurvePoints(newPoints, monitorId: monitorId);
    }
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, Map<String, SettingsState>>(
      SettingsNotifier.new,
    );

class CurrentBrightnessNotifier extends Notifier<double> {
  static const _lastBrightnessKey = 'last_known_brightness';

  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final lastBrightness = prefs?.getDouble(_lastBrightnessKey) ?? 100.0;

    final isAuto = ref.watch(autoAdjustmentProvider);
    if (isAuto) {
      final solarStateAsync = ref.watch(solarStateStreamProvider);
      final circadianService = ref.watch(circadianServiceProvider);
      final settingsAsync = ref.watch(settingsProvider);
      final monitorsAsync = ref.watch(monitorListProvider);
      final currentSelection = ref.watch(selectedMonitorIdProvider);

      return solarStateAsync.maybeWhen(
        data: (state) {
          // Apply brightness to ALL monitors in the background
          monitorsAsync.whenData((monitors) {
            settingsAsync.whenData((settingsMap) {
              for (final monitor in monitors) {
                final settings =
                    settingsMap[monitor.deviceName] ?? settingsMap['all']!;
                final target = circadianService.calculateTargetBrightness(
                  state.phases,
                  state.sunElevation,
                  DateTime.now(),
                  curveSharpness: settings.curveSharpness,
                  curvePoints: settings.curvePoints,
                );
                ref
                    .read(brightnessServiceProvider)
                    .applyBrightnessSmoothly(
                      selection: monitor.deviceName,
                      targetValue: target,
                      monitors: monitors,
                      monitorService: ref.read(monitorServiceProvider),
                      updateBrightnessCallback: (id, val) => ref
                          .read(monitorListProvider.notifier)
                          .updateBrightness(id, val),
                    );
              }
            });
          });

          // Return brightness for the CURRENTLY selected monitor in dashboard
          return settingsAsync.maybeWhen(
            data: (settingsMap) {
              final settingsId = currentSelection == 'all'
                  ? 'all'
                  : currentSelection;
              final selectedSettings =
                  settingsMap[settingsId] ?? settingsMap['all']!;
              final target = circadianService.calculateTargetBrightness(
                state.phases,
                state.sunElevation,
                DateTime.now(),
                curveSharpness: selectedSettings.curveSharpness,
                curvePoints: selectedSettings.curvePoints,
              );
              _saveBrightness(target);
              return target;
            },
            orElse: () => lastBrightness,
          );
        },
        orElse: () => lastBrightness,
      );
    } else {
      return ref.watch(manualBrightnessProvider);
    }
  }

  void _saveBrightness(double value) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setDouble(_lastBrightnessKey, value);
  }

  void setManualBrightness(double value) {
    ref.read(autoAdjustmentProvider.notifier).state = false;
    ref.read(manualBrightnessProvider.notifier).update(value);
    _saveBrightness(value);
  }
}

final currentBrightnessProvider =
    NotifierProvider<CurrentBrightnessNotifier, double>(
      CurrentBrightnessNotifier.new,
    );

/// Mapbox style URLs
const String kMapboxDayStyle = 'mapdezyk/cmmy53ap5001p01s92sw90jj9';
const String kMapboxNightStyle = 'mapdezyk/cmmy4n1dw007q01r0dyd1f6fs';

/// Generates a Mapbox Static Image URL for the given coordinates and style.
String getStaticMapUrl(
  double lat,
  double lon, {
  String style = kMapboxNightStyle,
  double zoom = 12.0,
}) {
  const token = String.fromEnvironment('MAPBOX_TOKEN');
  const width = 600;
  const height = 600;

  return 'https://api.mapbox.com/styles/v1/$style/static/$lon,$lat,$zoom,0,0/${width}x$height?access_token=$token&logo=false&attribution=false';
}
