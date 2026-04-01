import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'dart:math' as math;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/services/location_service.dart';
import 'package:solaris/services/time_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/services/sun_calculator_service.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/services/autorun_service.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/models/solar_state.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/services/smart_circadian_service.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:solaris/models/location_settings.dart' as model;
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/services/gaming_mode_service.dart';

final locationServiceProvider = Provider((ref) => LocationService());
final sunCalculatorServiceProvider = Provider((ref) => SunCalculatorService());
final timeServiceProvider = Provider((ref) => TimeService());
final monitorServiceProvider = Provider((ref) => MonitorService());
final circadianServiceProvider = Provider((ref) => CircadianService());
final brightnessServiceProvider = Provider((ref) => BrightnessService());
final storageServiceProvider = Provider((ref) => StorageService());
final smartCircadianServiceProvider = Provider<SmartCircadianService>(
  (ref) => SmartCircadianService(),
);

final gamingModeServiceProvider = Provider<GamingModeService>((ref) {
  return ref.watch<GamingModeService>(gamingModeProvider.notifier);
});

final smartCircadianDataProvider = Provider.family<SmartCircadianData, String>((
  ref,
  monitorId,
) {
  final regimes = ref.watch(sleepRegimesProvider);
  final service = ref.watch(smartCircadianServiceProvider);
  final settingsAsync = ref.watch(settingsProvider);
  final solarStateAsync = ref.watch(solarStateStreamProvider);
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();

  // Use 'all' as fallback if monitorId not found
  final settings = settingsAsync.value;
  if (settings == null) return const SmartCircadianData.neutral();

  final monitorSettings =
      settings[monitorId] ?? settings['all'] ?? SettingsState();

  return solarStateAsync.maybeWhen(
    data: (solar) {
      final smartData = service.calculateSmartAdjustments(
        regimes: regimes,
        now: now,
        astronomicalSunrise: solar.phases.sunrise,
        useSleepDebt:
            monitorSettings.isSleepDebtEnabled &&
            monitorSettings.isSleepDebtMasterEnabled,
        useSleepPressure:
            monitorSettings.isSleepPressureEnabled &&
            monitorSettings.isSleepPressureMasterEnabled,
        useTimeShift:
            monitorSettings.isTimeShiftEnabled &&
            monitorSettings.isTimeShiftMasterEnabled,
        useWindDown:
            monitorSettings.isWindDownEnabled &&
            monitorSettings.isWindDownMasterEnabled,
        sleepDebtBrightnessIntensity:
            monitorSettings.sleepDebtBrightnessIntensity,
        sleepDebtTemperatureIntensity:
            monitorSettings.sleepDebtTemperatureIntensity,
        sleepPressureBrightnessIntensity:
            monitorSettings.sleepPressureBrightnessIntensity,
        timeShiftIntensity: monitorSettings.timeShiftIntensity,
        windDownBrightnessIntensity:
            monitorSettings.windDownBrightnessIntensity,
        windDownTemperatureIntensity:
            monitorSettings.windDownTemperatureIntensity,
        windDownDurationMinutes: monitorSettings.windDownDurationMinutes,
        timeShiftDurationMinutes: monitorSettings.timeShiftDurationMinutes,
        sleepPressureWakeLimitHours:
            monitorSettings.sleepPressureWakeLimitHours,
        sleepDebtThresholdMinutes: monitorSettings.sleepDebtThresholdMinutes,
      );

      final weatherAsync = ref.watch(currentWeatherProvider);
      final circadianService = ref.watch(circadianServiceProvider);
      final sunService = ref.read(sunCalculatorServiceProvider);

      // Determine effective elevation for calculation (with time shift)
      double effectiveElevation = solar.sunElevation;
      double timeShiftImpact = 0;

      if (smartData.isTimeShiftActive) {
        final shiftedTime = now.subtract(smartData.timeOffset);
        final locationAsync = ref.watch(effectiveLocationProvider);
        final pos = locationAsync.value;

        if (pos != null) {
          effectiveElevation = sunService.getSunElevation(
            pos.latitude,
            pos.longitude,
            shiftedTime,
          );

          // Bio-morning is a bonus: never dim below natural sun level (for late risers)
          effectiveElevation = math.max(effectiveElevation, solar.sunElevation);

          // Blinding Protection (similar to other providers)
          if (solar.sunElevation < 0 && effectiveElevation > 10) {
            effectiveElevation = effectiveElevation.clamp(-20.0, 10.0);
          }

          // Calculate time shift impact for reference
          final baseResult = circadianService.calculateTargetBrightness(
            solar.phases,
            solar.sunElevation,
            now,
            curvePoints: monitorSettings.curvePoints,
          );
          final shiftedResult = circadianService.calculateTargetBrightness(
            solar.phases,
            effectiveElevation,
            now,
            curvePoints: monitorSettings.curvePoints,
          );
          timeShiftImpact =
              shiftedResult.finalBrightness - baseResult.finalBrightness;
        }
      }

      // Calculate Full Proportional Result
      final result = circadianService.calculateTargetBrightness(
        solar.phases,
        effectiveElevation,
        now,
        curvePoints: monitorSettings.curvePoints,
        weather: monitorSettings.isWeatherAdjustmentEnabled
            ? weatherAsync.value
            : null,
        presetSensitivity: monitorSettings.activePreset.weatherSensitivity,
        smartData: smartData,
      );

      // Resolve Active Preset Name
      String? activeUserPresetName;
      PresetType? activeSystemPreset;

      if (monitorSettings.activeUserPresetId != null) {
        try {
          activeUserPresetName = monitorSettings.userPresets
              .firstWhere((p) => p.id == monitorSettings.activeUserPresetId)
              .name;
        } catch (_) {
          activeSystemPreset = monitorSettings.activePreset;
        }
      } else {
        activeSystemPreset = monitorSettings.activePreset;
      }

      return smartData.copyWith(
        baseBrightness: result.baseBrightness,
        windDownAbsoluteImpact: result.windDownImpact,
        sleepPressureAbsoluteImpact: result.sleepPressureImpact,
        sleepDebtAbsoluteImpact: result.sleepDebtImpact,
        weatherAbsoluteImpact: result.weatherImpact,
        timeShiftBrightnessImpact: timeShiftImpact,
        weatherCode: weatherAsync.value?.weatherCode,
        activeSystemPreset: activeSystemPreset,
        activeUserPresetName: activeUserPresetName,
      );
    },
    orElse: () => const SmartCircadianData.neutral(),
  );
});

final smartCircadianTemperatureDataProvider =
    Provider.family<SmartCircadianData, String>((ref, monitorId) {
      final regimes = ref.watch(sleepRegimesProvider);
      final service = ref.watch(smartCircadianServiceProvider);
      final tempSettingsAsync = ref.watch(temperatureSettingsProvider);
      final solarStateAsync = ref.watch(solarStateStreamProvider);

      final settings = tempSettingsAsync.value;
      if (settings == null) return const SmartCircadianData.neutral();

      final monitorSettings =
          settings[monitorId] ?? settings['all'] ?? TemperatureState();

      final globalSettingsAsync = ref.watch(settingsProvider);
      final globalSettings = globalSettingsAsync.maybeWhen(
        data: (map) => map[monitorId] ?? map['all'] ?? SettingsState(),
        orElse: () => SettingsState(),
      );

      final now = ref.watch(currentTimeProvider).value ?? DateTime.now();

      return solarStateAsync.maybeWhen(
        data: (solar) => service.calculateSmartAdjustments(
          regimes: regimes,
          now: now,
          astronomicalSunrise: solar.phases.sunrise,
          useSleepDebt:
              monitorSettings.isSleepDebtEnabled &&
              globalSettings.isSleepDebtMasterEnabled,
          useSleepPressure:
              monitorSettings.isSleepPressureEnabled &&
              globalSettings.isSleepPressureMasterEnabled,
          useTimeShift:
              monitorSettings.isTimeShiftEnabled &&
              globalSettings.isTimeShiftMasterEnabled,
          useWindDown:
              monitorSettings.isWindDownEnabled &&
              globalSettings.isWindDownMasterEnabled,
          sleepDebtBrightnessIntensity:
              globalSettings.sleepDebtBrightnessIntensity,
          sleepDebtTemperatureIntensity:
              globalSettings.sleepDebtTemperatureIntensity,
          sleepPressureBrightnessIntensity:
              globalSettings.sleepPressureBrightnessIntensity,
          timeShiftIntensity: globalSettings.timeShiftIntensity,
          windDownBrightnessIntensity:
              globalSettings.windDownBrightnessIntensity,
          windDownTemperatureIntensity:
              globalSettings.windDownTemperatureIntensity,
          windDownDurationMinutes: globalSettings.windDownDurationMinutes,
          timeShiftDurationMinutes: globalSettings.timeShiftDurationMinutes,
          sleepPressureWakeLimitHours:
              globalSettings.sleepPressureWakeLimitHours,
          sleepDebtThresholdMinutes: globalSettings.sleepDebtThresholdMinutes,
        ),
        orElse: () => const SmartCircadianData.neutral(),
      );
    });

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

// SolarState moved to lib/models/solar_state.dart

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

final currentTimeProvider = StreamProvider<DateTime>((ref) async* {
  final visibility = ref.watch(appLifecycleProvider);

  // Adaptive delay for clock updates: 1s if visible, 1m if hidden
  final delay = visibility == AppVisibilityState.visible
      ? const Duration(seconds: 1)
      : const Duration(minutes: 1);

  while (true) {
    yield DateTime.now();
    await Future<void>.delayed(delay);
  }
});

/// Provider that emits the current solar state.
/// The frequency of updates is adaptive based on the app's visibility state:
/// - Visible: 1 second
/// - Minimized: 30 seconds
/// - Hidden (Tray): 60 seconds
final solarStateStreamProvider = StreamProvider<SolarState>((ref) async* {
  final service = ref.watch(sunCalculatorServiceProvider);
  final locationAsync = ref.watch(effectiveLocationProvider);
  final weatherAsync = ref.watch(currentWeatherProvider);
  final visibility = ref.watch(appLifecycleProvider);

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

  // Adaptive delay based on visibility
  final delaySeconds = switch (visibility) {
    AppVisibilityState.visible => 1,
    AppVisibilityState.minimized => 30,
    AppVisibilityState.hidden => 60,
  };

  // Immediate rough calculation to avoid "sun flash" at startup
  final initialNow = DateTime.now();
  final roughElevation = service.getSunElevation(lat, lon, initialNow);
  final roughAzimuth = service.getSunAzimuth(lat, lon, initialNow);
  final roughProgress = service.getSunProgress(phases, initialNow);
  final nextEvent = service.getNextEvent(phases, initialNow);

  yield SolarState(
    phases: phases,
    currentPhase: service.getCurrentPhase(phases, initialNow),
    timeUntilNextEvent: nextEvent.duration,
    nextEventType: nextEvent.type,
    sunElevation: roughElevation,
    sunAzimuth: roughAzimuth,
    sunZenith: service.getSunZenith(lat, lon, initialNow),
    sunProgress: roughProgress,
    uvIndex: service.getUVIndex(roughElevation),
    spectralIntensity: service.getSpectralIntensity(roughElevation),
    azimuthTrend: "constant",
    elevationTrend: "constant",
  );

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

    // Determine UV and Spectral Intensity
    double uv;
    double intensity;

    final weather = weatherAsync.value;
    if (weather != null) {
      uv = weather.uvIndex;
      intensity = weather.directRadiation + weather.diffuseRadiation;
    } else {
      uv = service.getUVIndex(currentElevation);
      intensity = service.getSpectralIntensity(currentElevation);
    }

    final nextEvent = service.getNextEvent(phases, now);

    yield SolarState(
      phases: phases,
      currentPhase: service.getCurrentPhase(phases, now),
      timeUntilNextEvent: nextEvent.duration,
      nextEventType: nextEvent.type,
      sunElevation: currentElevation,
      sunAzimuth: currentAzimuth,
      sunZenith: service.getSunZenith(lat, lon, now),
      sunProgress: service.getSunProgress(phases, now),
      uvIndex: uv,
      spectralIntensity: intensity,
      azimuthTrend: azTrend,
      elevationTrend: elTrend,
    );

    prevAzimuth = currentAzimuth;
    prevElevation = currentElevation;

    await Future<void>.delayed(Duration(seconds: delaySeconds));
  }
});

// solarDataProvider logic unified into solarStateStreamProvider

class MonitorListNotifier extends AsyncNotifier<List<MonitorInfo>> {
  @override
  Future<List<MonitorInfo>> build() async {
    return ref.watch(monitorServiceProvider).getConnectedMonitors();
  }

  void updateBrightness(String deviceName, int brightness) {
    _updateMonitor(deviceName, brightness, null);
  }

  void updateTemperature(String deviceName, int temperature) {
    _updateMonitor(deviceName, null, temperature);
  }

  void _updateMonitor(String deviceName, int? brightness, int? temperature) {
    state.whenData((monitors) {
      bool changed = false;
      final newList = monitors.map((m) {
        if (m.deviceName == deviceName) {
          final newBrightness = brightness ?? m.realBrightness;
          final newTemperature = temperature ?? m.realTemperature;
          if (newBrightness != m.realBrightness ||
              newTemperature != m.realTemperature) {
            changed = true;
            return MonitorInfo(
              name: m.name,
              friendlyName: m.friendlyName,
              deviceName: m.deviceName,
              isPrimary: m.isPrimary,
              realBrightness: newBrightness,
              realTemperature: newTemperature,
            );
          }
        }
        return m;
      }).toList();

      if (changed) {
        state = AsyncData(newList);
      }
    });
  }
}

final monitorListProvider =
    AsyncNotifierProvider<MonitorListNotifier, List<MonitorInfo>>(
      MonitorListNotifier.new,
    );

/// Provider for the monitor(s) currently being edited or controlled.
/// Default is {'all'}.
class SelectedMonitorsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {'all'};

  void toggle(String id) {
    if (id == 'all') {
      state = {'all'};
      return;
    }
    final newState = Set<String>.from(state);
    newState.remove('all');
    if (newState.contains(id)) {
      newState.remove(id);
    } else {
      newState.add(id);
    }
    state = newState;
  }

  void selectOnly(String id) => state = {id};
}

final selectedMonitorsProvider =
    NotifierProvider<SelectedMonitorsNotifier, Set<String>>(
      SelectedMonitorsNotifier.new,
    );

enum AppScreen { dashboard, schedule, sleep, settings, location }

class ActiveScreenNotifier extends Notifier<AppScreen> {
  @override
  AppScreen build() => AppScreen.dashboard;
  void setScreen(AppScreen screen) => state = screen;
}

final activeScreenProvider = NotifierProvider<ActiveScreenNotifier, AppScreen>(
  ActiveScreenNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  static const _localeKey = 'app_locale';

  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final languageCode = prefs?.getString(_localeKey);

    // Default to 'ru' to maintain previous behavior, but check if user saved 'en'
    if (languageCode == 'en') {
      return const Locale('en');
    }
    return const Locale('ru');
  }

  void setLocale(String languageCode) {
    if (languageCode != 'en' && languageCode != 'ru') return;
    state = Locale(languageCode);
    ref.read(sharedPreferencesProvider)?.setString(_localeKey, languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class AutoBrightnessAdjustmentNotifier extends Notifier<bool> {
  static const _autoBrightnessEnabledKey = 'auto_brightness_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final fastFlag = prefs?.getBool(_autoBrightnessEnabledKey);

    final settingsAsync = ref.watch(settingsProvider);
    final currentSelection = ref.watch(selectedMonitorsProvider);

    return settingsAsync.maybeWhen(
      data: (settingsMap) {
        final firstId = currentSelection.firstOrNull ?? 'all';
        final enabled =
            settingsMap[firstId]?.isAutoBrightnessEnabled ??
            settingsMap['all']?.isAutoBrightnessEnabled ??
            true;

        // Sync fast flag if different
        if (fastFlag != enabled) {
          prefs?.setBool(_autoBrightnessEnabledKey, enabled);
        }
        return enabled;
      },
      orElse: () => fastFlag ?? true,
    );
  }

  void setEnabled(bool value) {
    if (state == value) return;
    state = value;
    ref
        .read(sharedPreferencesProvider)
        ?.setBool(_autoBrightnessEnabledKey, value);
    ref.read(settingsProvider.notifier).updateAutoBrightness(value);
  }

  void toggle() {
    final currentState = state;
    if (currentState) {
      final monitor = _getBaselineMonitor(ref);
      if (monitor?.realBrightness != null) {
        ref
            .read(manualBrightnessProvider.notifier)
            .update(monitor!.realBrightness!.toDouble());
      }
    }

    setEnabled(!currentState);
  }
}

/// Finds the most relevant monitor to use as a baseline when switching modes.
MonitorInfo? _getBaselineMonitor(Ref ref) {
  final monitors = ref.read(monitorListProvider).value;
  if (monitors == null || monitors.isEmpty) return null;

  final selection = ref.read(selectedMonitorsProvider);
  final firstId = selection.firstOrNull ?? 'all';

  return monitors.firstWhere(
    (m) => m.deviceName == firstId,
    orElse: () => monitors.first,
  );
}

final autoBrightnessAdjustmentProvider =
    NotifierProvider<AutoBrightnessAdjustmentNotifier, bool>(
      AutoBrightnessAdjustmentNotifier.new,
    );

class AutoTemperatureAdjustmentNotifier extends Notifier<bool> {
  static const _autoTemperatureEnabledKey = 'auto_temperature_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final fastFlag = prefs?.getBool(_autoTemperatureEnabledKey);

    final tempSettingsAsync = ref.watch(temperatureSettingsProvider);
    final currentSelection = ref.watch(selectedMonitorsProvider);

    return tempSettingsAsync.maybeWhen(
      data: (tempSettingsMap) {
        final firstId = currentSelection.firstOrNull ?? 'all';
        final enabled =
            tempSettingsMap[firstId]?.isEnabled ??
            tempSettingsMap['all']?.isEnabled ??
            true;

        // Sync fast flag if different
        if (fastFlag != enabled) {
          prefs?.setBool(_autoTemperatureEnabledKey, enabled);
        }
        return enabled;
      },
      orElse: () => fastFlag ?? true,
    );
  }

  void toggle() {
    final currentState = state;
    if (currentState) {
      final monitor = _getBaselineMonitor(ref);
      if (monitor?.realTemperature != null) {
        ref
            .read(manualTemperatureProvider.notifier)
            .setTemperature(monitor!.realTemperature!);
      }
    }

    final newState = !currentState;
    ref
        .read(sharedPreferencesProvider)
        ?.setBool(_autoTemperatureEnabledKey, newState);
    ref.read(temperatureSettingsProvider.notifier).toggleEnabled(newState);
  }
}

final autoTemperatureAdjustmentProvider =
    NotifierProvider<AutoTemperatureAdjustmentNotifier, bool>(
      AutoTemperatureAdjustmentNotifier.new,
    );

class ManualBrightnessNotifier extends Notifier<double> {
  static const _manualBrightnessKey = 'manual_brightness';

  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs?.getDouble(_manualBrightnessKey) ?? 100.0;
  }

  void update(double value) {
    state = value;
    ref.read(sharedPreferencesProvider)?.setDouble(_manualBrightnessKey, value);
  }
}

final manualBrightnessProvider =
    NotifierProvider<ManualBrightnessNotifier, double>(
      ManualBrightnessNotifier.new,
    );

// SettingsState moved to lib/models/settings_state.dart

class SettingsNotifier extends AsyncNotifier<Map<String, SettingsState>> {
  static const _settingsFilename = 'monitor_settings.json';
  Timer? _saveTimer;

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
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      state.whenData((currentMap) async {
        final storage = ref.read(storageServiceProvider);
        final encoded = currentMap.map(
          (key, value) => MapEntry(key, value.toJson()),
        );
        await storage.save(_settingsFilename, jsonEncode(encoded));
      });
    });
  }

  SettingsState _getSettings(String monitorId) {
    final currentMap = state.value ?? {'all': SettingsState()};
    return currentMap[monitorId] ?? currentMap['all']!;
  }

  Future<void> _updateSettings(
    Set<String> monitorIds,
    SettingsState newState,
  ) async {
    final currentMap = state.value ?? {'all': SettingsState()};
    final newStateMap = Map<String, SettingsState>.from(currentMap);

    for (final id in monitorIds) {
      newStateMap[id] = newState;

      if (id == 'all') {
        // If updating 'all', replicate to all existing keys
        for (final key in newStateMap.keys.toList()) {
          if (key != 'all') {
            newStateMap[key] = newState;
          }
        }
      }
    }

    state = AsyncData(newStateMap);
    await _saveSettings();
  }

  void updateCurveSharpness(double value) {
    final ids = ref.read(selectedMonitorsProvider);
    // Use the first selected monitor's current settings as base
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(curveSharpness: value));
  }

  void updateAutorun(bool enabled) {
    final currentMap = state.value ?? {'all': SettingsState()};
    final current = currentMap['all']!;
    _updateSettings({'all'}, current.copyWith(isAutorunEnabled: enabled));
    AutorunService.setEnabled(enabled);
  }

  void updateWeatherAdjustment(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(isWeatherAdjustmentEnabled: enabled));
  }

  void updateGameModeEnabled(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(isGameModeEnabled: enabled));
  }

  void updateGameModeBrightness(double brightness) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(gameModeBrightness: brightness));
  }

  void addWhitelistItem(String item) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    if (!current.gameModeWhitelist.contains(item)) {
      final newList = List<String>.from(current.gameModeWhitelist)..add(item);
      _updateSettings(ids, current.copyWith(gameModeWhitelist: newList));
    }
  }

  void removeWhitelistItem(String item) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    if (current.gameModeWhitelist.contains(item)) {
      final newList = List<String>.from(current.gameModeWhitelist)
        ..remove(item);
      _updateSettings(ids, current.copyWith(gameModeWhitelist: newList));
    }
  }

  void addBlacklistItem(String item) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    if (!current.gameModeBlacklist.contains(item)) {
      final newList = List<String>.from(current.gameModeBlacklist)..add(item);
      _updateSettings(ids, current.copyWith(gameModeBlacklist: newList));
    }
  }

  void removeBlacklistItem(String item) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    if (current.gameModeBlacklist.contains(item)) {
      final newList = List<String>.from(current.gameModeBlacklist)
        ..remove(item);
      _updateSettings(ids, current.copyWith(gameModeBlacklist: newList));
    }
  }

  void updateAutoBrightness(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final firstId = ids.firstOrNull ?? 'all';
    final current = _getSettings(firstId);

    if (current.isAutoBrightnessEnabled == enabled) return;

    // Transitioning from Auto to Manual: Sync current hardware brightness to manual provider
    if (!enabled) {
      final monitor = _getBaselineMonitor(ref);
      if (monitor?.realBrightness != null) {
        ref
            .read(manualBrightnessProvider.notifier)
            .update(monitor!.realBrightness!.toDouble());
      }
    }

    ref
        .read(sharedPreferencesProvider)
        ?.setBool('auto_brightness_enabled', enabled);
    _updateSettings(ids, current.copyWith(isAutoBrightnessEnabled: enabled));
  }

  void updateSmartCircadian(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(isSmartCircadianEnabled: enabled));

    // Sync with temperature settings
    ref
        .read(temperatureSettingsProvider.notifier)
        .updateSmartCircadian(enabled);
  }

  void updateWindDownMaster(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(isWindDownMasterEnabled: enabled));
  }

  void updateTimeShiftMaster(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(isTimeShiftMasterEnabled: enabled));
  }

  void updateSleepPressureMaster(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(
      ids,
      current.copyWith(isSleepPressureMasterEnabled: enabled),
    );
  }

  void updateSleepDebtMaster(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(isSleepDebtMasterEnabled: enabled));
  }

  void updateSleepDebt(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(isSleepDebtEnabled: enabled));
  }

  void updateSleepPressure(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(isSleepPressureEnabled: enabled));
  }

  void updateTimeShift(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(isTimeShiftEnabled: enabled));
  }

  void updateWindDown(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(isWindDownEnabled: enabled));
  }

  void updateWindDownIntensity(double brightness, double temperature) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(
      ids,
      current.copyWith(
        windDownBrightnessIntensity: brightness,
        windDownTemperatureIntensity: temperature,
      ),
    );
  }

  void updateWindDownDuration(int minutes) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(windDownDurationMinutes: minutes));
  }

  void updateTimeShiftDuration(int minutes) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(timeShiftDurationMinutes: minutes));
  }

  void updateSleepPressureLimit(double hours) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(sleepPressureWakeLimitHours: hours));
  }

  void updateSleepDebtThreshold(int minutes) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(sleepDebtThresholdMinutes: minutes));
  }

  void updateSleepToleranceWindow(int value) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(sleepToleranceWindow: value));
  }

  void updateSleepMaxAnomalies(int value) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(sleepMaxAnomalies: value));
  }

  void updateSleepMinRegimeLength(int value) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(sleepMinRegimeLength: value));
  }

  void updateSleepAnchorSize(int value) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(sleepAnchorSize: value));
  }

  void updateSleepMaxSpread(int value) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(sleepMaxSpread: value));
  }

  void updateTimeShiftIntensity(double intensity) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(timeShiftIntensity: intensity));
  }

  void updateSleepPressureIntensity(double intensity) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(
      ids,
      current.copyWith(sleepPressureBrightnessIntensity: intensity),
    );
  }

  void updateSleepDebtIntensity(double brightness, double temperature) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(
      ids,
      current.copyWith(
        sleepDebtBrightnessIntensity: brightness,
        sleepDebtTemperatureIntensity: temperature,
      ),
    );
  }

  void updateCurvePoints(List<FlSpot> points) {
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

    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');

    if (current.activeUserPresetId != null) {
      final newUserPresets = current.userPresets.map((p) {
        if (p.id == current.activeUserPresetId) {
          return UserPreset(
            id: p.id,
            name: p.name,
            points: sortedPoints,
            initialPoints: p.initialPoints,
          );
        }
        return p;
      }).toList();
      _updateSettings(ids, current.copyWith(userPresets: newUserPresets));
    } else {
      final newCurvesMap = Map<PresetType, List<FlSpot>>.from(current.curvesMap);
      newCurvesMap[current.activePreset] = sortedPoints;
      _updateSettings(ids, current.copyWith(curvesMap: newCurvesMap));
    }
  }

  void addCurvePoint(FlSpot point) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    final newPoints = List<FlSpot>.from(current.curvePoints)..add(point);
    updateCurvePoints(newPoints);
  }

  void removeCurvePoint(int index) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    if (index >= 0 && index < current.curvePoints.length) {
      if (current.curvePoints[index].x == -20 ||
          current.curvePoints[index].x == 90)
        return;
      final newPoints = List<FlSpot>.from(current.curvePoints)..removeAt(index);
      updateCurvePoints(newPoints);
    }
  }

  void setActivePreset(PresetType type) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(
      ids,
      current.copyWith(activePreset: type, clearActiveUserPresetId: true),
    );
  }

  void setActiveUserPreset(String id) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    _updateSettings(ids, current.copyWith(activeUserPresetId: id));
  }

  void saveAsNewPreset(String name) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    final newPreset = UserPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      points: List<FlSpot>.from(current.curvePoints),
      initialPoints: List<FlSpot>.from(current.curvePoints),
    );
    final newUserPresets = List<UserPreset>.from(current.userPresets)
      ..add(newPreset);
    final newPresetOrder = List<String>.from(current.presetOrder)
      ..add('user:${newPreset.id}');
    _updateSettings(
      ids,
      current.copyWith(
        userPresets: newUserPresets,
        activeUserPresetId: newPreset.id,
        presetOrder: newPresetOrder,
      ),
    );
  }

  void deleteUserPreset(String id) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    final newUserPresets = current.userPresets.where((p) => p.id != id).toList();
    final newPresetOrder =
        current.presetOrder.where((orderId) => orderId != 'user:$id').toList();

    String? newActiveId = current.activeUserPresetId;
    if (newActiveId == id) {
      newActiveId = newUserPresets.isNotEmpty ? newUserPresets.first.id : null;
    }

    _updateSettings(
      ids,
      current.copyWith(
        userPresets: newUserPresets,
        activeUserPresetId: newActiveId,
        presetOrder: newPresetOrder,
      ),
    );
  }

  void reorderAllPresets(int oldIndex, int newIndex) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    final newOrder = List<String>.from(current.presetOrder);

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);

    _updateSettings(ids, current.copyWith(presetOrder: newOrder));
  }

  void renameUserPreset(String id, String newName) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    final newUserPresets = current.userPresets.map((p) {
      if (p.id == id) {
        return UserPreset(
          id: p.id,
          name: newName,
          points: p.points,
          initialPoints: p.initialPoints,
        );
      }
      return p;
    }).toList();

    _updateSettings(ids, current.copyWith(userPresets: newUserPresets));
  }

  void resetCurrentPreset() {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');

    if (current.activeUserPresetId != null) {
      final newUserPresets = current.userPresets.map((p) {
        if (p.id == current.activeUserPresetId) {
          return UserPreset(
            id: p.id,
            name: p.name,
            points: List<FlSpot>.from(p.initialPoints),
            initialPoints: List<FlSpot>.from(p.initialPoints),
          );
        }
        return p;
      }).toList();
      _updateSettings(ids, current.copyWith(userPresets: newUserPresets));
      return;
    }

    final presetType = current.activePreset;

    final newCurvesMap = Map<PresetType, List<FlSpot>>.from(current.curvesMap);
    newCurvesMap[presetType] = PresetConstants.getDefaultPoints(presetType);

    _updateSettings(ids, current.copyWith(curvesMap: newCurvesMap));
  }

  void cyclePreset({required bool brighter}) {
    final ids = ref.read(selectedMonitorsProvider);
    final id = ids.firstOrNull ?? 'all';
    final current = _getSettings(id);

    // Filter out 'system:custom' and map to objects
    final cycleOrder = current.presetOrder
        .where((orderId) => orderId != 'system:custom')
        .map((orderId) {
      if (orderId.startsWith('system:')) {
        final typeName = orderId.substring(7);
        try {
          return PresetType.values.firstWhere((e) => e.name == typeName);
        } catch (_) {
          return PresetType.bright;
        }
      } else {
        final userId = orderId.substring(5);
        try {
          return current.userPresets.firstWhere((p) => p.id == userId);
        } catch (_) {
          return null;
        }
      }
    }).where((item) => item != null).toList();

    if (cycleOrder.isEmpty) return;

    int currentIndex = -1;
    if (current.activeUserPresetId != null) {
      currentIndex = cycleOrder.indexWhere(
        (p) => p is UserPreset && p.id == current.activeUserPresetId,
      );
    } else {
      currentIndex = cycleOrder.indexOf(current.activePreset);
    }

    if (currentIndex == -1) {
      // Default to the first preset in the list if current state is unknown
      final next = cycleOrder.first;
      if (next is PresetType) {
        setActivePreset(next);
      } else if (next is UserPreset) {
        setActiveUserPreset(next.id);
      }
      return;
    }

    // Directionality:
    // next_preset (brighter: true) -> Forward in list (index + 1)
    // prev_preset (brighter: false) -> Backward in list (index - 1)
    int newIndex;
    if (brighter) {
      newIndex = (currentIndex + 1) % cycleOrder.length;
    } else {
      newIndex = (currentIndex - 1 + cycleOrder.length) % cycleOrder.length;
    }

    final next = cycleOrder[newIndex];
    if (next is PresetType) {
      setActivePreset(next);
    } else if (next is UserPreset) {
      setActiveUserPreset(next.id);
    }
  }

  void adjustManualBrightness(double delta) {
    updateAutoBrightness(false);
    final currentManual = ref.read(manualBrightnessProvider);
    final newVal = (currentManual + delta).clamp(0.0, 100.0);
    ref.read(manualBrightnessProvider.notifier).update(newVal);

    // Save to prefs as well (matches setManualBrightness in CurrentBrightnessNotifier)
    ref
        .read(sharedPreferencesProvider)
        ?.setDouble('last_known_brightness', newVal);
  }

  void updateBrightnessStep(bool isUp, double value) {
    final ids = ref.read(selectedMonitorsProvider);
    final current = _getSettings(ids.firstOrNull ?? 'all');
    if (isUp) {
      _updateSettings(ids, current.copyWith(brightnessStepUp: value));
    } else {
      _updateSettings(ids, current.copyWith(brightnessStepDown: value));
    }
  }

  void updateHotkey(String field, Map<String, dynamic>? hotKeyJson) {
    // Hotkeys are global app settings, so we update 'all'
    final currentMap = state.value ?? {'all': SettingsState()};
    final current = currentMap['all']!;

    if (field == 'next_preset') {
      _updateSettings(
        {'all'},
        current.copyWith(
          nextPresetHotKey: hotKeyJson,
          clearNextPresetHotKey: hotKeyJson == null,
        ),
      );
    } else if (field == 'prev_preset') {
      _updateSettings(
        {'all'},
        current.copyWith(
          prevPresetHotKey: hotKeyJson,
          clearPrevPresetHotKey: hotKeyJson == null,
        ),
      );
    } else if (field == 'brightness_up') {
      _updateSettings(
        {'all'},
        current.copyWith(
          brightnessUpHotKey: hotKeyJson,
          clearBrightnessUpHotKey: hotKeyJson == null,
        ),
      );
    } else if (field == 'brightness_down') {
      _updateSettings(
        {'all'},
        current.copyWith(
          brightnessDownHotKey: hotKeyJson,
          clearBrightnessDownHotKey: hotKeyJson == null,
        ),
      );
    } else if (field == 'auto_brightness_toggle') {
      _updateSettings(
        {'all'},
        current.copyWith(
          autoBrightnessHotKey: hotKeyJson,
          clearAutoBrightnessHotKey: hotKeyJson == null,
        ),
      );
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

    final isAuto = ref.watch(autoBrightnessAdjustmentProvider);
    final currentSelection = ref.watch(selectedMonitorsProvider);
    final manualBrightness = ref.watch(manualBrightnessProvider);
    final firstId = currentSelection.firstOrNull ?? 'all';
    final smartData = ref.watch(smartCircadianDataProvider(firstId));

    if (isAuto) {
      final solarStateAsync = ref.watch(solarStateStreamProvider);
      final circadianService = ref.watch(circadianServiceProvider);
      final settingsAsync = ref.watch(settingsProvider);
      final weatherAsync = ref.watch(currentWeatherProvider);

      return solarStateAsync.maybeWhen(
        data: (state) {
          return settingsAsync.maybeWhen(
            data: (settingsMap) {
              final selectedSettings =
                  settingsMap[firstId] ?? settingsMap['all']!;

              if (!selectedSettings.isAutoBrightnessEnabled) {
                return manualBrightness;
              }

              final effectiveSmartData =
                  selectedSettings.isSmartCircadianEnabled
                  ? smartData
                  : const SmartCircadianData.neutral();

              // Calculate Bio-Morning Shift (Shifted Elevation)
              double effectiveElevation = state.sunElevation;
              if (selectedSettings.isSmartCircadianEnabled &&
                  effectiveSmartData.timeOffset != Duration.zero) {
                final locationAsync = ref.read(effectiveLocationProvider);
                final pos = locationAsync.value;
                if (pos != null) {
                  final sunService = ref.read(sunCalculatorServiceProvider);
                  final shiftedTime = DateTime.now().subtract(
                    effectiveSmartData.timeOffset,
                  );
                  effectiveElevation = sunService.getSunElevation(
                    pos.latitude,
                    pos.longitude,
                    shiftedTime,
                  );

                  // Blinding Protection
                  if (state.sunElevation < 0 && effectiveElevation > 10) {
                    effectiveElevation = effectiveElevation.clamp(-20.0, 10.0);
                  }
                }
              }

              final result = circadianService.calculateTargetBrightness(
                state.phases,
                effectiveElevation,
                DateTime.now(),
                curveSharpness: selectedSettings.curveSharpness,
                curvePoints: selectedSettings.curvePoints,
                weather: selectedSettings.isWeatherAdjustmentEnabled
                    ? weatherAsync.value
                    : null,
                presetSensitivity:
                    selectedSettings.activePreset.weatherSensitivity,
                smartData: effectiveSmartData,
              );
              _saveBrightness(result.finalBrightness);
              return result.finalBrightness;
            },
            orElse: () => lastBrightness,
          );
        },
        orElse: () => lastBrightness,
      );
    } else {
      return manualBrightness;
    }
  }

  void _saveBrightness(double value) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setDouble(_lastBrightnessKey, value);
  }

  void setManualBrightness(double value) {
    ref.read(settingsProvider.notifier).updateAutoBrightness(false);
    ref.read(manualBrightnessProvider.notifier).update(value);
    _saveBrightness(value);
  }
}

final currentBrightnessProvider =
    NotifierProvider<CurrentBrightnessNotifier, double>(
      CurrentBrightnessNotifier.new,
    );

/// Background provider that manages monitor brightness and temperature adjustments.
/// It listens to solar state and applies brightness updates to hardware.
/// If the app is minimized, it skips UI state updates to save resources.
final circadianAdjustmentProvider = Provider<void>((ref) {
  // Watch all required providers to ensure consistency and immediate reaction
  final solarStateAsync = ref.watch(solarStateStreamProvider);
  final settingsAsync = ref.watch(settingsProvider);
  final tempSettingsAsync = ref.watch(temperatureSettingsProvider);
  final monitorsAsync = ref.read(monitorListProvider);
  final visibility = ref.watch(appLifecycleProvider);
  final weatherAsync = ref.watch(currentWeatherProvider);

  // Watch extra providers that were previously illegal in callbacks
  final primaryId = ref.watch(selectedMonitorsProvider).firstOrNull ?? 'all';
  final smartDataProvider = smartCircadianDataProvider(primaryId);
  final smartData = ref.watch(smartDataProvider);
  final isGamingMode = ref.watch<bool>(gamingModeProvider);
  final smartTempData = ref.watch(
    smartCircadianTemperatureDataProvider(primaryId),
  );

  final circadianService = ref.read(circadianServiceProvider);
  final brightnessService = ref.read(brightnessServiceProvider);
  final tempService = ref.read(temperatureServiceProvider);
  final monitorService = ref.read(monitorServiceProvider);
  final isTempEnabled = ref.read(isColorTemperatureEnabledProvider);
  final monitorListNotifier = ref.read(monitorListProvider.notifier);

  solarStateAsync.whenData((state) {
    monitorsAsync.whenData((monitors) {
      settingsAsync.whenData((settingsMap) {
        tempSettingsAsync.whenData((tempSettingsMap) {
          for (final monitor in monitors) {
            final settings =
                settingsMap[monitor.deviceName] ?? settingsMap['all']!;
            final tempSettings =
                tempSettingsMap[monitor.deviceName] ?? tempSettingsMap['all']!;

            // Calculate and Apply Brightness
            if (settings.isAutoBrightnessEnabled) {
              final effectiveSmartData = settings.isSmartCircadianEnabled
                  ? smartData
                  : const SmartCircadianData.neutral();

              double effectiveElevation = state.sunElevation;
              if (settings.isSmartCircadianEnabled &&
                  effectiveSmartData.timeOffset != Duration.zero) {
                final locationAsync = ref.read(effectiveLocationProvider);
                final pos = locationAsync.value;
                if (pos != null) {
                  final sunService = ref.read(sunCalculatorServiceProvider);
                  final shiftedTime = DateTime.now().subtract(
                    effectiveSmartData.timeOffset,
                  );
                  effectiveElevation = sunService.getSunElevation(
                    pos.latitude,
                    pos.longitude,
                    shiftedTime,
                  );

                  if (state.sunElevation < 0 && effectiveElevation > 10) {
                    effectiveElevation = effectiveElevation.clamp(-20.0, 10.0);
                  }
                }
              }

              double targetBrightness;
              CircadianCalculationResult? calculationResult;

              if (isGamingMode && settings.isGameModeEnabled) {
                targetBrightness = settings.gameModeBrightness;
              } else {
                calculationResult = circadianService.calculateTargetBrightness(
                  state.phases,
                  effectiveElevation,
                  DateTime.now(),
                  curveSharpness: settings.curveSharpness,
                  curvePoints: settings.curvePoints,
                  weather: settings.isWeatherAdjustmentEnabled
                      ? weatherAsync.value
                      : null,
                  presetSensitivity: settings.activePreset.weatherSensitivity,
                  smartData: effectiveSmartData,
                );
                targetBrightness = calculationResult.finalBrightness;
              }

              brightnessService.applyBrightnessSmoothly(
                selection: monitor.deviceName,
                targetValue: targetBrightness,
                monitors: monitors,
                monitorService: monitorService,
                isUIVisible: visibility == AppVisibilityState.visible,
                updateBrightnessCallback: (id, val) {
                  // ONLY update the UI provider if the app is visible
                  if (visibility == AppVisibilityState.visible) {
                    monitorListNotifier.updateBrightness(id, val);
                  }
                },
              );
            }

            // Calculate and Apply Temperature
            if (tempSettings.isEnabled && isTempEnabled) {
              final effectiveSmartTempData =
                  tempSettings.isSmartCircadianEnabled
                  ? smartTempData
                  : const SmartCircadianData.neutral();

              double effectiveElevation = state.sunElevation;
              if (tempSettings.isSmartCircadianEnabled &&
                  effectiveSmartTempData.timeOffset != Duration.zero) {
                final locationAsync = ref.read(effectiveLocationProvider);
                final pos = locationAsync.value;
                if (pos != null) {
                  final sunService = ref.read(sunCalculatorServiceProvider);
                  final shiftedTime = DateTime.now().subtract(
                    effectiveSmartTempData.timeOffset,
                  );
                  effectiveElevation = sunService.getSunElevation(
                    pos.latitude,
                    pos.longitude,
                    shiftedTime,
                  );

                  if (state.sunElevation < 0 && effectiveElevation > 10) {
                    effectiveElevation = effectiveElevation.clamp(-20.0, 10.0);
                  }
                }
              }

              final targetTemp = circadianService.calculateTargetTemperature(
                state.phases,
                effectiveElevation,
                DateTime.now(),
                curvePoints: tempSettings.curvePoints,
                weather: weatherAsync.value,
                smartData: effectiveSmartTempData,
              );

              tempService.applyTemperatureSmoothly(
                selection: monitor.deviceName,
                targetValue: targetTemp.toDouble(),
                monitors: monitors,
                monitorService: monitorService,
                isUIVisible: visibility == AppVisibilityState.visible,
                updateTemperatureCallback: (id, val) {},
              );
            } else {
              // Disabled means no further temperature writes from circadian loop.
              tempService.stopTemperatureControlForDevice(monitor.deviceName);
            }
          }
        });
      });
    });
  });
});

class NightModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final isAuto = ref.watch(autoNightModeProvider);
    if (isAuto) {
      final solarStateAsync = ref.watch(solarStateStreamProvider);
      return solarStateAsync.maybeWhen(
        data: (state) => state.sunProgress < 0 || state.sunProgress > 1,
        orElse: () => false,
      );
    }
    return false;
  }

  void toggle() {
    state = !state;
    // If user toggles manually, we disable auto night mode
    ref.read(autoNightModeProvider.notifier).state = false;
  }
}

final nightModeProvider = NotifierProvider<NightModeNotifier, bool>(
  NightModeNotifier.new,
);

class AutoNightModeNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
  void setEnabled(bool value) => state = value;
}

final autoNightModeProvider = NotifierProvider<AutoNightModeNotifier, bool>(
  AutoNightModeNotifier.new,
);

/// Mapbox style URLs
const String kMapboxDayStyle = 'mapdezyk/cmmy53ap5001p01s92sw90jj9';
const String kMapboxNightStyle = 'mapdezyk/cmnc5qn0r005v01qtdh606sjs';
const String kMapboxLargeMapStyle = 'mapdezyk/cmmzahwi7005201r0fllj7v0r';

/// Generates a Mapbox Static Image URL for the given coordinates and style.
String getStaticMapUrl(
  double lat,
  double lon, {
  String style = kMapboxNightStyle,
  double zoom = 15.1,
}) {
  const token = String.fromEnvironment('MAPBOX_TOKEN');
  const width = 600;
  const height = 600;

  return 'https://api.mapbox.com/styles/v1/$style/static/$lon,$lat,$zoom,0,0/${width}x$height?access_token=$token&logo=false&attribution=false';
}
