import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/services/location_service.dart';
import 'package:solaris/services/solar_service.dart';
import 'package:solaris/services/time_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/services/sun_calculator_service.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'dart:async';

final locationServiceProvider = Provider((ref) => LocationService());
final solarServiceProvider = Provider(
  (ref) => SolarService(),
); // Keep for now or remove if unused elsewhere
final sunCalculatorServiceProvider = Provider((ref) => SunCalculatorService());
final timeServiceProvider = Provider((ref) => TimeService());
final monitorServiceProvider = Provider((ref) => MonitorService());
final circadianServiceProvider = Provider((ref) => CircadianService());

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

class CurrentBrightnessNotifier extends Notifier<double> {
  @override
  double build() {
    final isAuto = ref.watch(autoAdjustmentProvider);
    if (isAuto) {
      final solarStateAsync = ref.watch(solarStateStreamProvider);
      final circadianService = ref.watch(circadianServiceProvider);

      return solarStateAsync.maybeWhen(
        data: (state) => circadianService.calculateTargetBrightness(
          state.phases,
          state.sunElevation,
          DateTime.now(),
        ),
        orElse: () => ref.read(manualBrightnessProvider),
      );
    } else {
      return ref.watch(manualBrightnessProvider);
    }
  }

  void setManualBrightness(double value) {
    ref.read(autoAdjustmentProvider.notifier).state = false;
    ref.read(manualBrightnessProvider.notifier).update(value);
  }
}

final currentBrightnessProvider =
    NotifierProvider<CurrentBrightnessNotifier, double>(
      CurrentBrightnessNotifier.new,
    );

/// Generates a Mapbox Static Image URL for the given coordinates.
String getStaticMapUrl(double lat, double lon) {
  const token = String.fromEnvironment('MAPBOX_TOKEN');
  const zoom = 10.5;
  const width = 600;
  const height = 600;

  return 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/$lon,$lat,$zoom,0,0/${width}x$height?access_token=$token&logo=false&attribution=false';
}
