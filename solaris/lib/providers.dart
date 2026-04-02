import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

class IsSearchVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void setVisible(bool visible) => state = visible;
  void toggle() => state = !state;
}

final isSearchVisibleProvider = NotifierProvider<IsSearchVisibleNotifier, bool>(
  IsSearchVisibleNotifier.new,
);

class SearchAnchorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setAnchor(String? anchor) => state = anchor;
  void clear() => state = null;
}

final searchAnchorProvider = NotifierProvider<SearchAnchorNotifier, String?>(
  SearchAnchorNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  static const _localeKey = 'app_locale';

  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final languageCode = prefs?.getString(_localeKey);

    if (languageCode != null) {
      return Locale(languageCode);
    }

    // Detect system locale if no user preference is saved
    try {
      final systemLocale = PlatformDispatcher.instance.locale;
      if (systemLocale.languageCode.startsWith('ru')) {
        return const Locale('ru');
      }
      if (systemLocale.languageCode.startsWith('uk')) {
        return const Locale('uk');
      }
    } catch (e) {
      debugPrint('Error detecting system locale: $e');
    }

    // Default to English for all other system languages
    return const Locale('en');
  }

  void setLocale(String languageCode) {
    if (languageCode != 'en' && languageCode != 'ru' && languageCode != 'uk') return;
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
        final settingsAsync = ref.read(settingsProvider);
        final settings = settingsAsync.value?[monitor!.deviceName] ??
            settingsAsync.value?['all'] ??
            SettingsState();

        ref
            .read(manualBrightnessProvider.notifier)
            .update(
              (monitor!.realBrightness! - settings.brightnessOffset).clamp(
                0.0,
                100.0,
              ).toDouble(),
            );
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
    SettingsState Function(SettingsState) transform,
  ) async {
    final currentMap = state.value ?? {'all': SettingsState()};
    final newStateMap = Map<String, SettingsState>.from(currentMap);

    for (final id in monitorIds) {
      if (id == 'all') {
        newStateMap['all'] = transform(newStateMap['all']!);
        // Replicate CHANGE to all other specific monitors without overwriting their unique fields
        for (final key in newStateMap.keys.toList()) {
          if (key != 'all') {
            newStateMap[key] = transform(newStateMap[key]!);
          }
        }
      } else {
        newStateMap[id] = transform(newStateMap[id]!);
      }
    }

    state = AsyncData(newStateMap);
    await _saveSettings();
  }

  void updateCurveSharpness(double value) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(curveSharpness: value),
    );
  }

  void updateAutorun(bool enabled) {
    _updateSettings(
      {'all'}, // Autorun is globally replicated
      (s) => s.copyWith(isAutorunEnabled: enabled),
    );
    AutorunService.setEnabled(enabled);
  }

  void updateWeatherAdjustment(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isWeatherAdjustmentEnabled: enabled),
    );
  }

  void updateGameModeEnabled(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isGameModeEnabled: enabled),
    );
  }

  void updateGameModeBrightness(double brightness) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(gameModeBrightness: brightness),
    );
  }

  void addWhitelistItem(String item) {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      if (!s.gameModeWhitelist.contains(item)) {
        final newList = List<String>.from(s.gameModeWhitelist)..add(item);
        return s.copyWith(gameModeWhitelist: newList);
      }
      return s;
    });
  }

  void removeWhitelistItem(String item) {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      if (s.gameModeWhitelist.contains(item)) {
        final newList = List<String>.from(s.gameModeWhitelist)..remove(item);
        return s.copyWith(gameModeWhitelist: newList);
      }
      return s;
    });
  }

  void addBlacklistItem(String item) {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      if (!s.gameModeBlacklist.contains(item)) {
        final newList = List<String>.from(s.gameModeBlacklist)..add(item);
        return s.copyWith(gameModeBlacklist: newList);
      }
      return s;
    });
  }

  void removeBlacklistItem(String item) {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      if (s.gameModeBlacklist.contains(item)) {
        final newList = List<String>.from(s.gameModeBlacklist)..remove(item);
        return s.copyWith(gameModeBlacklist: newList);
      }
      return s;
    });
  }

  void updateAutoBrightness(bool enabled) {
    final ids = ref.read(selectedMonitorsProvider);
    final firstId = ids.firstOrNull ?? 'all';
    final current = _getSettings(firstId);

    // Only perform sync if we are actually switching from Auto to Manual
    if (current.isAutoBrightnessEnabled && !enabled) {
      final monitor = _getBaselineMonitor(ref);
      if (monitor?.realBrightness != null) {
        final monitorSettings = _getSettings(monitor!.deviceName);
        ref.read(manualBrightnessProvider.notifier).update(
              (monitor.realBrightness! - monitorSettings.brightnessOffset)
                  .clamp(0.0, 100.0)
                  .toDouble(),
            );
      }
    }

    ref
        .read(sharedPreferencesProvider)
        ?.setBool('auto_brightness_enabled', enabled);
    _updateSettings(ids, (s) => s.copyWith(isAutoBrightnessEnabled: enabled));
  }

  void updateSmartCircadian(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isSmartCircadianEnabled: enabled),
    );

    // Sync with temperature settings
    ref
        .read(temperatureSettingsProvider.notifier)
        .updateSmartCircadian(enabled);
  }

  void updateWindDownMaster(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isWindDownMasterEnabled: enabled),
    );
  }

  void updateTimeShiftMaster(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isTimeShiftMasterEnabled: enabled),
    );
  }

  void updateSleepPressureMaster(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isSleepPressureMasterEnabled: enabled),
    );
  }

  void updateSleepDebtMaster(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isSleepDebtMasterEnabled: enabled),
    );
  }

  void updateSleepDebt(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isSleepDebtEnabled: enabled),
    );
  }

  void updateSleepPressure(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isSleepPressureEnabled: enabled),
    );
  }

  void updateTimeShift(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isTimeShiftEnabled: enabled),
    );
  }

  void updateWindDown(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isWindDownEnabled: enabled),
    );
  }

  void updateWindDownIntensity(double brightness, double temperature) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(
        windDownBrightnessIntensity: brightness,
        windDownTemperatureIntensity: temperature,
      ),
    );
  }

  void updateWindDownDuration(int minutes) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(windDownDurationMinutes: minutes),
    );
  }

  void updateTimeShiftDuration(int minutes) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(timeShiftDurationMinutes: minutes),
    );
  }

  void updateSleepPressureLimit(double hours) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(sleepPressureWakeLimitHours: hours),
    );
  }

  void updateSleepDebtThreshold(int minutes) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(sleepDebtThresholdMinutes: minutes),
    );
  }

  void updateSleepToleranceWindow(int value) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(sleepToleranceWindow: value),
    );
  }

  void updateSleepMaxAnomalies(int value) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(sleepMaxAnomalies: value),
    );
  }

  void updateSleepMinRegimeLength(int value) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(sleepMinRegimeLength: value),
    );
  }

  void updateSleepAnchorSize(int value) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(sleepAnchorSize: value),
    );
  }

  void updateSleepMaxSpread(int value) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(sleepMaxSpread: value),
    );
  }

  void updateTimeShiftIntensity(double intensity) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(timeShiftIntensity: intensity),
    );
  }

  void updateSleepPressureIntensity(double intensity) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(sleepPressureBrightnessIntensity: intensity),
    );
  }

  void updateSleepDebtIntensity(double brightness, double temperature) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(
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

    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      if (s.activeUserPresetId != null) {
        final newUserPresets = s.userPresets.map((p) {
          if (p.id == s.activeUserPresetId) {
            return UserPreset(
              id: p.id,
              name: p.name,
              points: sortedPoints,
              initialPoints: p.initialPoints,
            );
          }
          return p;
        }).toList();
        return s.copyWith(userPresets: newUserPresets);
      } else {
        final newCurvesMap = Map<PresetType, List<FlSpot>>.from(s.curvesMap);
        newCurvesMap[s.activePreset] = sortedPoints;
        return s.copyWith(curvesMap: newCurvesMap);
      }
    });
  }

  void addCurvePoint(FlSpot point) {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      final newPoints = List<FlSpot>.from(s.curvePoints)..add(point);
      // Helper to update curve points within the transform
      return _updatePointsInState(s, newPoints);
    });
  }

  void removeCurvePoint(int index) {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      if (index >= 0 && index < s.curvePoints.length) {
        if (s.curvePoints[index].x == -20 || s.curvePoints[index].x == 90)
          return s;
        final newPoints = List<FlSpot>.from(s.curvePoints)..removeAt(index);
        return _updatePointsInState(s, newPoints);
      }
      return s;
    });
  }

  SettingsState _updatePointsInState(SettingsState s, List<FlSpot> points) {
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

    if (s.activeUserPresetId != null) {
      final newUserPresets = s.userPresets.map((p) {
        if (p.id == s.activeUserPresetId) {
          return UserPreset(
            id: p.id,
            name: p.name,
            points: sortedPoints,
            initialPoints: p.initialPoints,
          );
        }
        return p;
      }).toList();
      return s.copyWith(userPresets: newUserPresets);
    } else {
      final newCurvesMap = Map<PresetType, List<FlSpot>>.from(s.curvesMap);
      newCurvesMap[s.activePreset] = sortedPoints;
      return s.copyWith(curvesMap: newCurvesMap);
    }
  }

  void setActivePreset(PresetType type) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(activePreset: type, clearActiveUserPresetId: true),
    );
  }

  void updateMultiMonitorOffsetEnabled(bool enabled) {
    _updateSettings(
      {'all'},
      (s) => s.copyWith(isMultiMonitorOffsetEnabled: enabled),
    );
  }

  void updateMonitorOffset(String monitorId, double offset) {
    _updateSettings({monitorId}, (s) => s.copyWith(brightnessOffset: offset));
  }

  void setActiveUserPreset(String id) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(activeUserPresetId: id),
    );
  }

  void saveAsNewPreset(String name) {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      final newPreset = UserPreset(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        points: List<FlSpot>.from(s.curvePoints),
        initialPoints: List<FlSpot>.from(s.curvePoints),
      );
      final newUserPresets = List<UserPreset>.from(s.userPresets)
        ..add(newPreset);
      final newPresetOrder = List<String>.from(s.presetOrder)
        ..add('user:${newPreset.id}');
      return s.copyWith(
        userPresets: newUserPresets,
        activeUserPresetId: newPreset.id,
        presetOrder: newPresetOrder,
      );
    });
  }

  void deleteUserPreset(String id) {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      final newUserPresets = s.userPresets.where((p) => p.id != id).toList();
      final newPresetOrder =
          s.presetOrder.where((orderId) => orderId != 'user:$id').toList();

      String? newActiveId = s.activeUserPresetId;
      if (newActiveId == id) {
        newActiveId = newUserPresets.isNotEmpty ? newUserPresets.first.id : null;
      }

      return s.copyWith(
        userPresets: newUserPresets,
        activeUserPresetId: newActiveId,
        presetOrder: newPresetOrder,
      );
    });
  }

  void reorderAllPresets(int oldIndex, int newIndex) {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      final newOrder = List<String>.from(s.presetOrder);
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = newOrder.removeAt(oldIndex);
      newOrder.insert(newIndex, item);
      return s.copyWith(presetOrder: newOrder);
    });
  }

  void renameUserPreset(String id, String newName) {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      final newUserPresets = s.userPresets.map((p) {
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
      return s.copyWith(userPresets: newUserPresets);
    });
  }

  void resetCurrentPreset() {
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      if (s.activeUserPresetId != null) {
        final newUserPresets = s.userPresets.map((p) {
          if (p.id == s.activeUserPresetId) {
            return UserPreset(
              id: p.id,
              name: p.name,
              points: List<FlSpot>.from(p.initialPoints),
              initialPoints: List<FlSpot>.from(p.initialPoints),
            );
          }
          return p;
        }).toList();
        return s.copyWith(userPresets: newUserPresets);
      }

      final presetType = s.activePreset;
      final newCurvesMap = Map<PresetType, List<FlSpot>>.from(s.curvesMap);
      newCurvesMap[presetType] = PresetConstants.getDefaultPoints(presetType);
      return s.copyWith(curvesMap: newCurvesMap);
    });
  }

  void cyclePreset({required bool brighter}) {
    // Cycling is complex because it depends on the current state of each monitor.
    // We update each selected monitor based on its own cycle order.
    _updateSettings(ref.read(selectedMonitorsProvider), (s) {
      final cycleOrder = s.presetOrder
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
            return s.userPresets.firstWhere((p) => p.id == userId);
          } catch (_) {
            return null;
          }
        }
      }).where((item) => item != null).toList();

      if (cycleOrder.isEmpty) return s;

      int currentIndex = -1;
      if (s.activeUserPresetId != null) {
        currentIndex = cycleOrder.indexWhere(
          (p) => p is UserPreset && p.id == s.activeUserPresetId,
        );
      } else {
        currentIndex = cycleOrder.indexOf(s.activePreset);
      }

      if (currentIndex == -1) {
        final next = cycleOrder.first;
        if (next is PresetType) {
          return s.copyWith(activePreset: next, clearActiveUserPresetId: true);
        } else if (next is UserPreset) {
          return s.copyWith(activeUserPresetId: next.id);
        }
        return s;
      }

      int newIndex;
      if (brighter) {
        newIndex = (currentIndex + 1) % cycleOrder.length;
      } else {
        newIndex = (currentIndex - 1 + cycleOrder.length) % cycleOrder.length;
      }

      final next = cycleOrder[newIndex];
      if (next is PresetType) {
        return s.copyWith(activePreset: next, clearActiveUserPresetId: true);
      } else if (next is UserPreset) {
        return s.copyWith(activeUserPresetId: next.id);
      }
      return s;
    });
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
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) =>
          isUp
              ? s.copyWith(brightnessStepUp: value)
              : s.copyWith(brightnessStepDown: value),
    );
  }

  void updateHotkey(String field, Map<String, dynamic>? hotKeyJson) {
    _updateSettings({'all'}, (s) {
      if (field == 'next_preset') {
        return s.copyWith(
          nextPresetHotKey: hotKeyJson,
          clearNextPresetHotKey: hotKeyJson == null,
        );
      } else if (field == 'prev_preset') {
        return s.copyWith(
          prevPresetHotKey: hotKeyJson,
          clearPrevPresetHotKey: hotKeyJson == null,
        );
      } else if (field == 'brightness_up') {
        return s.copyWith(
          brightnessUpHotKey: hotKeyJson,
          clearBrightnessUpHotKey: hotKeyJson == null,
        );
      } else if (field == 'brightness_down') {
        return s.copyWith(
          brightnessDownHotKey: hotKeyJson,
          clearBrightnessDownHotKey: hotKeyJson == null,
        );
      } else if (field == 'auto_brightness_toggle') {
        return s.copyWith(
          autoBrightnessHotKey: hotKeyJson,
          clearAutoBrightnessHotKey: hotKeyJson == null,
        );
      }
      return s;
    });
  }

  void updateShowRainAnimation(bool val) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(showRainAnimation: val),
    );
  }

  void updateShowSnowAnimation(bool val) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(showSnowAnimation: val),
    );
  }

  void updateShowThunderAnimation(bool val) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(showThunderAnimation: val),
    );
  }

  void updateShowCloudAnimation(bool val) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(showCloudAnimation: val),
    );
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

    double baseValue = value;
    final selection = ref.read(selectedMonitorsProvider);
    if (selection.length == 1 && !selection.contains('all')) {
      final id = selection.first;
      final offsets = ref.read(brightnessOffsetsProvider);
      final offset = offsets[id] ?? 0.0;
      baseValue = (value - offset).clamp(0.0, 100.0);
    }

    ref.read(manualBrightnessProvider.notifier).update(baseValue);
    _saveBrightness(baseValue);
  }
}

final currentBrightnessProvider =
    NotifierProvider<CurrentBrightnessNotifier, double>(
      CurrentBrightnessNotifier.new,
    );

final brightnessOffsetsProvider = Provider<Map<String, double>>((ref) {
  final settingsAsync = ref.watch(settingsProvider);
  return settingsAsync.maybeWhen(
    data: (settingsMap) {
      final allSettings = settingsMap['all'] ?? SettingsState();
      if (!allSettings.isMultiMonitorOffsetEnabled) return {};

      final Map<String, double> offsets = {};
      settingsMap.forEach((id, s) {
        if (id != 'all') {
          offsets[id] = s.brightnessOffset;
        }
      });
      return offsets;
    },
    orElse: () => {},
  );
});

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

              final offsets = ref.watch(brightnessOffsetsProvider);

              brightnessService.applyBrightnessSmoothly(
                selection: monitor.deviceName,
                targetValue: targetBrightness,
                monitors: monitors,
                monitorService: monitorService,
                offsets: offsets,
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
  final token = dotenv.get('MAPBOX_TOKEN', fallback: '');
  const width = 600;
  const height = 600;

  return 'https://api.mapbox.com/styles/v1/$style/static/$lon,$lat,$zoom,0,0/${width}x$height?access_token=$token&logo=false&attribution=false';
}
