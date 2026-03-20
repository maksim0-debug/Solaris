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
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/services/autorun_service.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

final locationServiceProvider = Provider((ref) => LocationService());
final solarServiceProvider = Provider(
  (ref) => SolarService(),
); // Keep for now or remove if unused elsewhere
final sunCalculatorServiceProvider = Provider((ref) => SunCalculatorService());
final timeServiceProvider = Provider((ref) => TimeService());
final monitorServiceProvider = Provider((ref) => MonitorService());
final circadianServiceProvider = Provider((ref) => CircadianService());

// Провайдер для SharedPreferences (переопределяется в main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// 1. Провайдер самого сервиса
final weatherServiceProvider = Provider((ref) => WeatherService());

// 2. Асинхронный провайдер данных о погоде
final currentWeatherProvider = FutureProvider<WeatherData?>((ref) async {
  final locationAsync = ref.watch(locationStreamProvider);
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

final currentTimeProvider = StreamProvider<DateTime>((ref) {
  final service = ref.watch(timeServiceProvider);
  return service.getTimeStream();
});

/// Provider that emits the current solar state every second.
final solarStateStreamProvider = StreamProvider<SolarState>((ref) async* {
  final service = ref.watch(sunCalculatorServiceProvider);
  final locationAsync = ref.watch(locationStreamProvider);

  // Use location from stream, or default to Kyiv if loading
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
  final double minBrightness;
  final double maxBrightness;
  final double transBrightness;
  final double curveSharpness;
  final List<FlSpot> curvePoints;
  final bool isAutorunEnabled;

  SettingsState({
    this.minBrightness = 15.0,
    this.maxBrightness = 100.0,
    this.transBrightness = 60.0,
    this.curveSharpness = 1.0,
    this.isAutorunEnabled = false,
    List<FlSpot>? curvePoints,
  }) : curvePoints = curvePoints ?? _defaultPoints();

  // Теперь точки базируются на угле солнца (от -20° до 90°)
  static List<FlSpot> _defaultPoints() => const [
    FlSpot(-20, 15), // Глубокая ночь (Астрономические сумерки)
    FlSpot(-6, 25), // Начало гражданских сумерек (рассвет/закат)
    FlSpot(0, 60), // Солнце на горизонте
    FlSpot(10, 85), // Утро / Вечер (конец золотого часа)
    FlSpot(30, 100), // Яркий день
    FlSpot(90, 100), // Абсолютный зенит
  ];

  SettingsState copyWith({
    double? minBrightness,
    double? maxBrightness,
    double? transBrightness,
    double? curveSharpness,
    List<FlSpot>? curvePoints,
    bool? isAutorunEnabled,
  }) {
    return SettingsState(
      minBrightness: minBrightness ?? this.minBrightness,
      maxBrightness: maxBrightness ?? this.maxBrightness,
      transBrightness: transBrightness ?? this.transBrightness,
      curveSharpness: curveSharpness ?? this.curveSharpness,
      curvePoints: curvePoints ?? this.curvePoints,
      isAutorunEnabled: isAutorunEnabled ?? this.isAutorunEnabled,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const _pointsKey = 'solar_curve_points';
  static const _minBrightnessKey = 'solar_min_brightness';
  static const _maxBrightnessKey = 'solar_max_brightness';
  static const _transBrightnessKey = 'solar_trans_brightness';
  static const _curveSharpnessKey = 'solar_curve_sharpness';
  static const _autorunKey = 'app_autorun_enabled';

  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _loadSettings(prefs);
  }

  // Загрузка всех настроек из памяти
  SettingsState _loadSettings(SharedPreferences prefs) {
    final String? jsonStr = prefs.getString(_pointsKey);
    List<FlSpot>? points;
    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
        points = decoded.map((p) {
          final map = p as Map<String, dynamic>;
          return FlSpot(
            (map['x'] as num).toDouble(),
            (map['y'] as num).toDouble(),
          );
        }).toList();
      } catch (e) {
        print('Error loading points: $e');
      }
    }

    return SettingsState(
      minBrightness: prefs.getDouble(_minBrightnessKey) ?? 15.0,
      maxBrightness: prefs.getDouble(_maxBrightnessKey) ?? 100.0,
      transBrightness: prefs.getDouble(_transBrightnessKey) ?? 60.0,
      curveSharpness: prefs.getDouble(_curveSharpnessKey) ?? 1.0,
      isAutorunEnabled: prefs.getBool(_autorunKey) ?? false,
      curvePoints: points,
    );
  }

  // Сохранение всех настроек в память
  void _saveSettings() {
    final prefs = ref.read(sharedPreferencesProvider);
    final encoded = state.curvePoints.map((p) => {'x': p.x, 'y': p.y}).toList();

    prefs.setString(_pointsKey, jsonEncode(encoded));
    prefs.setDouble(_minBrightnessKey, state.minBrightness);
    prefs.setDouble(_maxBrightnessKey, state.maxBrightness);
    prefs.setDouble(_transBrightnessKey, state.transBrightness);
    prefs.setDouble(_curveSharpnessKey, state.curveSharpness);
    prefs.setBool(_autorunKey, state.isAutorunEnabled);
  }

  void updateMinBrightness(double value) {
    state = state.copyWith(minBrightness: value);
    _saveSettings();
  }

  void updateMaxBrightness(double value) {
    state = state.copyWith(maxBrightness: value);
    _saveSettings();
  }

  void updateTransBrightness(double value) {
    state = state.copyWith(transBrightness: value);
    _saveSettings();
  }

  void updateCurveSharpness(double value) {
    state = state.copyWith(curveSharpness: value);
    _saveSettings();
  }

  void updateAutorun(bool enabled) {
    state = state.copyWith(isAutorunEnabled: enabled);
    _saveSettings();
    AutorunService.setEnabled(enabled);
  }

  void updateCurvePoints(List<FlSpot> points) {
    final sortedPoints = List<FlSpot>.from(points)
      ..sort((a, b) => a.x.compareTo(b.x));

    // Гарантируем, что края графика (-20 и 90) всегда присутствуют
    if (sortedPoints.isEmpty || sortedPoints.first.x > -20) {
      sortedPoints.insert(
        0,
        FlSpot(-20, sortedPoints.isEmpty ? 15 : sortedPoints.first.y),
      );
    }
    if (sortedPoints.last.x < 90) {
      sortedPoints.add(FlSpot(90, sortedPoints.last.y));
    }

    state = state.copyWith(curvePoints: sortedPoints);
    _saveSettings(); // Сохраняем при каждом изменении
  }

  void addCurvePoint(FlSpot point) {
    final newPoints = List<FlSpot>.from(state.curvePoints)..add(point);
    updateCurvePoints(newPoints);
  }

  void removeCurvePoint(int index) {
    if (index >= 0 && index < state.curvePoints.length) {
      if (state.curvePoints[index].x == -20 || state.curvePoints[index].x == 90)
        return;
      final newPoints = List<FlSpot>.from(state.curvePoints)..removeAt(index);
      updateCurvePoints(newPoints);
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

class CurrentBrightnessNotifier extends Notifier<double> {
  static const _lastBrightnessKey = 'last_known_brightness';

  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final lastBrightness = prefs.getDouble(_lastBrightnessKey) ?? 100.0;

    final isAuto = ref.watch(autoAdjustmentProvider);
    if (isAuto) {
      final solarStateAsync = ref.watch(solarStateStreamProvider);
      final circadianService = ref.watch(circadianServiceProvider);
      final settings = ref.watch(settingsProvider);

      return solarStateAsync.maybeWhen(
        data: (state) {
          final target = circadianService.calculateTargetBrightness(
            state.phases,
            state.sunElevation,
            DateTime.now(),
            minBrightness: settings.minBrightness,
            maxBrightness: settings.maxBrightness,
            transBrightness: settings.transBrightness,
            curveSharpness: settings.curveSharpness,
            curvePoints: settings.curvePoints,
          );
          _saveBrightness(target);
          return target;
        },
        orElse: () => lastBrightness,
      );
    } else {
      return ref.watch(manualBrightnessProvider);
    }
  }

  void _saveBrightness(double value) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setDouble(_lastBrightnessKey, value);
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
}) {
  const token = String.fromEnvironment('MAPBOX_TOKEN');
  const zoom = 13.2; // Slightly closer zoom for better "city lights" effect
  const width = 600;
  const height = 600;

  return 'https://api.mapbox.com/styles/v1/$style/static/$lon,$lat,$zoom,0,0/${width}x$height?access_token=$token&logo=false&attribution=false';
}
