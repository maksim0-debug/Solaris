import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:solaris/env/env.dart';
import 'package:solaris/services/local_ipc_service.dart';
import 'package:solaris/models/local_ipc_server_state.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/services/location_service.dart';
import 'package:solaris/services/geocoding_service.dart';
import 'package:solaris/services/time_service.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/services/sun_calculator_service.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:solaris/services/autorun_service.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/models/solar_state.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/models/webhook_config.dart';
import 'package:solaris/services/webhook_service.dart';
import 'package:solaris/utils/key_obfuscator.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/models/brightness_target.dart';
import 'package:solaris/services/smart_circadian_service.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:solaris/models/location_settings.dart' as model;
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/services/gaming_mode_service.dart';
import 'package:solaris/services/map_health_service.dart';
import 'package:solaris/models/map_health_report.dart';
export 'package:solaris/providers/update_provider.dart';
export 'package:solaris/providers/post_update_provider.dart';
export 'package:solaris/models/post_update_result.dart';
export 'package:solaris/providers/expanded_gamma_provider.dart';
import 'package:solaris/services/windows_firewall_service.dart';
import 'package:solaris/services/websocket_service.dart';
import 'package:solaris/services/windows_power_listener.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/services/active_process_service.dart';
import 'package:collection/collection.dart';
import 'package:solaris/services/log_service.dart';
export 'package:solaris/services/post_update_service.dart';
export 'package:solaris/providers/app_info_provider.dart';
export 'package:solaris/services/log_service.dart';

final logServiceProvider = Provider((ref) => LogService.instance);
final locationServiceProvider = Provider((ref) => LocationService());
final sunCalculatorServiceProvider = Provider((ref) => SunCalculatorService());
final timeServiceProvider = Provider((ref) => TimeService());
final monitorServiceProvider = Provider((ref) {
  final service = MonitorService();
  ref.onDispose(service.dispose);
  return service;
});
final circadianServiceProvider = Provider((ref) => CircadianService());
final brightnessServiceProvider = Provider((ref) {
  final service = BrightnessService();
  ref.onDispose(service.dispose);
  return service;
});
final storageServiceProvider = Provider((ref) => StorageService());
final smartCircadianServiceProvider = Provider<SmartCircadianService>(
  (ref) => SmartCircadianService(),
);
final mapHealthServiceProvider = Provider((ref) => MapHealthService());
final windowsFirewallServiceProvider = Provider(
  (ref) => WindowsFirewallService(),
);
final webSocketServiceProvider = Provider((ref) => WebSocketService(ref));
final windowsPowerListenerProvider = Provider(
  (ref) => WindowsPowerListener(ref),
);

final localIpcServiceProvider =
    NotifierProvider<LocalIpcService, LocalIpcServerState>(LocalIpcService.new);

final gamingModeServiceProvider = Provider<GamingModeService>((ref) {
  return ref.watch<GamingModeService>(gamingModeProvider.notifier);
});

final minuteTimeProvider = StreamProvider<DateTime>((ref) {
  final timezoneVal = ref.watch(effectiveTimezoneProvider);
  final visibility = ref.watch(appLifecycleProvider);
  final now = tz.TZDateTime.now(timezoneVal);
  final delayUntilNextMinute = Duration(
    seconds: 60 - now.second,
    milliseconds: 1000 - now.millisecond,
  );

  // When hidden to tray, reduce update frequency to every 5 minutes
  // to lower GC pressure and CPU usage (~1-2 MB heap savings)
  final intervalMinutes = visibility == AppVisibilityState.hidden ? 5 : 1;

  StreamController<DateTime> controller = StreamController();

  // Emit initial values
  controller.add(now);

  Timer? initialTimer;
  Timer? periodicTimer;

  // In test environments, emit initial value and close controller without pending timer
  if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
    ref.onDispose(() {
      controller.close();
    });
    return controller.stream;
  }

  initialTimer = Timer(delayUntilNextMinute, () {
    if (!controller.isClosed) {
      controller.add(tz.TZDateTime.now(timezoneVal));
    }
    periodicTimer = Timer.periodic(Duration(minutes: intervalMinutes), (_) {
      if (!controller.isClosed) {
        controller.add(tz.TZDateTime.now(timezoneVal));
      }
    });
  });

  ref.onDispose(() {
    initialTimer?.cancel();
    periodicTimer?.cancel();
    controller.close();
  });

  return controller.stream;
});

final smartCircadianAdjustmentsProvider =
    Provider.family<SmartCircadianData, String>((ref, monitorId) {
      final settingsAsync = ref.watch(settingsProvider);
      final solarStateAsync = ref.watch(debouncedSolarStateProvider);
      final timezoneVal = ref.watch(effectiveTimezoneProvider);
      final now =
          ref.watch(minuteTimeProvider).value ?? tz.TZDateTime.now(timezoneVal);

      // Use 'all' as fallback if monitorId not found
      final settings = settingsAsync.value;
      if (settings == null) return const SmartCircadianData.neutral();

      final monitorSettings =
          settings[monitorId] ?? settings['all'] ?? SettingsState();

      if (!monitorSettings.isSmartCircadianEnabled) {
        return const SmartCircadianData.neutral();
      }
      final regimes = ref.watch(sleepRegimesProvider);
      final service = ref.watch(smartCircadianServiceProvider);
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
            sleepPressureTemperatureIntensity:
                monitorSettings.sleepPressureTemperatureIntensity,
            timeShiftBrightnessIntensity:
                monitorSettings.timeShiftBrightnessIntensity,
            timeShiftTemperatureIntensity:
                monitorSettings.timeShiftTemperatureIntensity,
            timeShiftIntensity: monitorSettings.timeShiftBrightnessIntensity,
            windDownBrightnessIntensity:
                monitorSettings.windDownBrightnessIntensity,
            windDownTemperatureIntensity:
                monitorSettings.windDownTemperatureIntensity,
            windDownDurationMinutes: monitorSettings.windDownDurationMinutes,
            timeShiftDurationMinutes: monitorSettings.timeShiftDurationMinutes,
            sleepPressureWakeLimitHours:
                monitorSettings.sleepPressureWakeLimitHours,
            sleepDebtThresholdMinutes:
                monitorSettings.sleepDebtThresholdMinutes,
          );

          return smartData;
        },
        orElse: () => const SmartCircadianData.neutral(),
      );
    });

SmartCircadianData? _calculateBrightnessData(
  Ref ref,
  SettingsState settings,
  SmartCircadianData smartData, {
  List<FlSpot>? curvePoints,
  CircadianMode? mode,
  double? presetSensitivity,
}) {
  final solar = ref.watch(debouncedSolarStateProvider).value;
  if (solar == null) return null;
  final timezone = ref.watch(effectiveTimezoneProvider);
  final now =
      ref.watch(minuteTimeProvider).value ?? tz.TZDateTime.now(timezone);
  final effectiveSmart = settings.isSmartCircadianEnabled
      ? smartData
      : const SmartCircadianData.neutral();
  double elevation = solar.sunElevation;
  if (effectiveSmart.timeOffset != Duration.zero) {
    final location = ref.watch(effectiveLocationProvider).value;
    if (location != null) {
      elevation = ref
          .watch(sunCalculatorServiceProvider)
          .getSunElevation(
            location.latitude,
            location.longitude,
            now.subtract(effectiveSmart.timeOffset),
          );
      if (solar.sunElevation < 0 && elevation > 10) {
        elevation = elevation.clamp(-20, 10);
      }
    }
  }
  final weather = ref.watch(currentWeatherProvider).value;
  final result = ref
      .watch(circadianServiceProvider)
      .calculateTargetBrightness(
        solar.phases,
        elevation,
        now,
        unshiftedElevation: solar.sunElevation,
        curvePoints: curvePoints ?? settings.curvePoints,
        weather: settings.isWeatherAdjustmentEnabled ? weather : null,
        presetSensitivity:
            presetSensitivity ?? settings.activePreset.weatherSensitivity,
        weatherIntensity: settings.weatherAdjustmentIntensity,
        smartData: effectiveSmart,
        circadianMode: mode ?? settings.circadianMode,
        phasesConfig: settings.phasesConfig,
        maxElevation: solar.maxElevation,
        minElevation: solar.minElevation,
      );
  return effectiveSmart.copyWith(
    basePhase: result.basePhase,
    baseBrightness: result.baseBrightness,
    finalBrightness: result.finalBrightness,
    elevationShiftBrightnessImpact: result.elevationShiftImpact,
    brightnessLimitImpact: result.limitImpact,
    weatherAbsoluteImpact: result.weatherImpact,
    windDownAbsoluteImpact: result.windDownImpact,
    sleepPressureAbsoluteImpact: result.sleepPressureImpact,
    sleepDebtAbsoluteImpact: result.sleepDebtImpact,
    timeShiftBrightnessImpact: result.timeShiftImpact,
    weatherCode: weather?.weatherCode,
  );
}

final smartCircadianDataProvider = Provider.family<SmartCircadianData, String>((
  ref,
  id,
) {
  final map = ref.watch(settingsProvider).value;
  if (map == null) return const SmartCircadianData.neutral();
  final settings = map[id] ?? map['all'] ?? SettingsState();
  final data = _calculateBrightnessData(
    ref,
    settings,
    ref.watch(smartCircadianAdjustmentsProvider(id)),
  );
  final preset = settings.userPresets.firstWhereOrNull(
    (p) => p.id == settings.activeUserPresetId,
  );
  return (data ?? const SmartCircadianData.neutral()).copyWith(
    activeSystemPreset: preset == null ? settings.activePreset : null,
    activeUserPresetName: preset?.name,
  );
});

/// Resolves the same priority cascade for the UI and every individual display.
/// A missing automatic snapshot means wait for solar data, never invent a base.
final brightnessTargetProvider = Provider.family<BrightnessTarget?, String>((
  ref,
  id,
) {
  final map = ref.watch(settingsProvider).value;
  if (map == null) return null;
  final settings = map[id] ?? map['all'] ?? SettingsState();
  final rule = resolveActiveAppRule(
    settings,
    map['all'],
    ref.watch(activeProcessServiceProvider),
  );

  BrightnessTarget fixed(
    BrightnessSource source,
    double value, {
    String? application,
  }) => BrightnessTarget(
    source: source,
    data: const SmartCircadianData.neutral().copyWith(
      baseBrightness: value,
      finalBrightness: value,
    ),
    applicationName: application,
  );

  if (rule?.brightnessMode == AppOverrideMode.fixed) {
    return fixed(
      BrightnessSource.appFixed,
      rule!.effectiveFixedBrightness,
      application: rule.appDisplayName,
    );
  }
  if (rule?.brightnessMode == AppOverrideMode.curve) {
    final presetId = rule!.brightnessCurvePresetId;
    final user = settings.userPresets.firstWhereOrNull((p) => p.id == presetId);
    final system = PresetType.values.firstWhereOrNull(
      (p) => p.name == presetId,
    );
    final points = user?.points ?? settings.curvesMap[system];
    if (points != null && points.isNotEmpty) {
      final data = _calculateBrightnessData(
        ref,
        settings,
        ref.watch(smartCircadianAdjustmentsProvider(id)),
        curvePoints: points,
        mode: CircadianMode.normalizedCurve,
        presetSensitivity: (system ?? settings.activePreset).weatherSensitivity,
      );
      if (data == null) return null;
      return BrightnessTarget(
        source: BrightnessSource.appCurve,
        data: data,
        systemPreset: user == null ? system : null,
        userPresetName: user?.name,
        applicationName: rule.appDisplayName,
      );
    }
  }
  if (ref.watch(gamingModeProvider) && settings.isGameModeEnabled) {
    return fixed(
      BrightnessSource.game,
      settings.gameModeBrightness.clamp(0, 100),
    );
  }
  if (!settings.isAutoBrightnessEnabled) {
    final monitors = ref.watch(monitorListProvider).value ?? [];
    final selection = id == 'all' ? {'all'} : {id};
    final minimum = MonitorInfo.effectiveMinBrightness(
      isOverlayOnly: MonitorInfo.isSelectionOverlayOnly(selection, monitors),
      isSoftwareDimmingEnabled: map['all']?.isSoftwareDimmingEnabled ?? true,
    );
    return fixed(
      BrightnessSource.manual,
      ref.watch(manualBrightnessProvider).clamp(minimum, 100),
    );
  }
  final data = ref.watch(smartCircadianDataProvider(id));
  if (data.finalBrightness == null) return null;
  return BrightnessTarget(
    source: settings.circadianMode == CircadianMode.solarPhases
        ? BrightnessSource.solarPhases
        : BrightnessSource.curve,
    data: data,
    systemPreset: data.activeSystemPreset,
    userPresetName: data.activeUserPresetName,
  );
});

final smartCircadianTemperatureDataProvider =
    Provider.family<SmartCircadianData, String>((ref, monitorId) {
      final regimes = ref.watch(sleepRegimesProvider);
      final service = ref.watch(smartCircadianServiceProvider);
      final tempSettingsAsync = ref.watch(temperatureSettingsProvider);
      final solarStateAsync = ref.watch(debouncedSolarStateProvider);
      final weatherAsync = ref.watch(currentWeatherProvider);
      final circadianService = ref.watch(circadianServiceProvider);

      final settings = tempSettingsAsync.value;
      if (settings == null) return const SmartCircadianData.neutral();

      final monitorSettings =
          settings[monitorId] ?? settings['all'] ?? TemperatureState();

      final globalSettingsAsync = ref.watch(settingsProvider);
      final globalSettings = globalSettingsAsync.maybeWhen(
        data: (map) => map[monitorId] ?? map['all'] ?? SettingsState(),
        orElse: () => SettingsState(),
      );

      final timezoneVal = ref.watch(effectiveTimezoneProvider);
      final now =
          ref.watch(minuteTimeProvider).value ?? tz.TZDateTime.now(timezoneVal);

      return solarStateAsync.maybeWhen(
        data: (solar) {
          final smartData =
              !globalSettings.isSmartCircadianEnabled ||
                  !monitorSettings.isSmartCircadianEnabled
              ? const SmartCircadianData.neutral()
              : service.calculateSmartAdjustments(
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
                  sleepPressureTemperatureIntensity:
                      globalSettings.sleepPressureTemperatureIntensity,
                  timeShiftBrightnessIntensity:
                      globalSettings.timeShiftBrightnessIntensity,
                  timeShiftTemperatureIntensity:
                      globalSettings.timeShiftTemperatureIntensity,
                  timeShiftIntensity:
                      globalSettings.timeShiftBrightnessIntensity,
                  windDownBrightnessIntensity:
                      globalSettings.windDownBrightnessIntensity,
                  windDownTemperatureIntensity:
                      globalSettings.windDownTemperatureIntensity,
                  windDownDurationMinutes:
                      globalSettings.windDownDurationMinutes,
                  timeShiftDurationMinutes:
                      globalSettings.timeShiftDurationMinutes,
                  sleepPressureWakeLimitHours:
                      globalSettings.sleepPressureWakeLimitHours,
                  sleepDebtThresholdMinutes:
                      globalSettings.sleepDebtThresholdMinutes,
                );

          // Calculate temperature breakdown for tooltip
          final tempResult = circadianService.calculateTargetTemperature(
            solar.phases,
            solar.sunElevation,
            now,
            curvePoints: monitorSettings.curvePoints,
            weather: globalSettings.isWeatherTemperatureAdjustmentEnabled
                ? weatherAsync.value
                : null,
            weatherIntensity: globalSettings.weatherAdjustmentIntensity,
            smartData: smartData,
            circadianMode: globalSettings.circadianMode,
            phasesConfig: globalSettings.phasesConfig,
            maxElevation: solar.maxElevation,
            minElevation: solar.minElevation,
          );

          // Resolve Active Preset Name for Temperature
          String? activeUserTempPresetName;
          TemperaturePresetType? activeSystemTempPreset;

          if (monitorSettings.activeUserPresetId != null) {
            try {
              activeUserTempPresetName = monitorSettings.userPresets
                  .firstWhere((p) => p.id == monitorSettings.activeUserPresetId)
                  .name;
            } catch (_) {
              activeSystemTempPreset = monitorSettings.activePreset;
            }
          } else {
            activeSystemTempPreset = monitorSettings.activePreset;
          }

          return smartData.copyWith(
            basePhase: tempResult.basePhase,
            baseTemperature: tempResult.baseTemperature,
            weatherTemperatureImpact: tempResult.weatherImpact,
            timeShiftTemperatureImpact: tempResult.timeShiftImpact,
            sleepPressureTemperatureImpact: tempResult.sleepPressureImpact,
            windDownTemperatureImpact: tempResult.windDownImpact,
            sleepDebtTemperatureImpact: tempResult.sleepDebtImpact,
            weatherCode: weatherAsync.value?.weatherCode,
            activeSystemTemperaturePreset: activeSystemTempPreset,
            activeUserTemperaturePresetName: activeUserTempPresetName,
            finalTemperature: tempResult.finalTemperature,
            temperatureLimitImpact: tempResult.limitImpact,
            temperatureRoundingImpact: tempResult.roundingImpact,
          );
        },
        orElse: () => const SmartCircadianData.neutral(),
      );
    });

// SharedPreferences provider (overridden in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

// 1. Service provider
final weatherServiceProvider = Provider((ref) => WeatherService());

class WeatherNotifier extends AsyncNotifier<WeatherData?> {
  Timer? _timer;
  static WeatherData? _lastKnownWeather;

  @override
  Future<WeatherData?> build() async {
    final coordsAvailable = ref.watch(coordinatesAvailableProvider);
    final weatherService = ref.watch(weatherServiceProvider);
    final (provider, customWeatherApiKey) = ref.watch(
      settingsProvider.select((settings) {
        final global = settings.value?['all'];
        return (
          global?.weatherProvider ?? WeatherProvider.auto,
          global?.customWeatherApiKey,
        );
      }),
    );

    // Clean up old timer on disposal
    ref.onDispose(() {
      _timer?.cancel();
    });

    if (!coordsAvailable) {
      _timer?.cancel();
      _lastKnownWeather = null;
      return null;
    }

    final locationAsync = ref.watch(effectiveLocationProvider);

    // Retrieve current location (preserving previous state during loading)
    final pos = locationAsync.value;

    _setupTimer(pos, provider, weatherService);

    if (pos == null) {
      return _lastKnownWeather;
    }

    try {
      final newData = await weatherService.fetchCurrentWeather(
        pos.latitude,
        pos.longitude,
        provider: provider,
        customApiKey: customWeatherApiKey,
      );

      if (newData != null) {
        _lastKnownWeather = newData;
      }
    } catch (e) {
      debugPrint(
        'CurrentWeather provider caught error: $e. Retaining previous weather state.',
      );
    }

    return _lastKnownWeather;
  }

  void _setupTimer(
    Position? pos,
    WeatherProvider provider,
    WeatherService weatherService,
  ) {
    _timer?.cancel();
    if (pos == null) return;

    _timer = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        final newData = await weatherService.fetchCurrentWeather(
          pos.latitude,
          pos.longitude,
          provider: provider,
        );
        if (newData != null) {
          _lastKnownWeather = newData;
          // Update state asynchronously so Riverpod does not reset it to null
          state = AsyncData(newData);
        }
      } catch (e) {
        // Error or timeout - preserve the previous state
        debugPrint(
          'Timer update caught error: $e. Retaining previous weather state.',
        );
      }
    });
  }
}

final currentWeatherProvider =
    AsyncNotifierProvider<WeatherNotifier, WeatherData?>(() {
      return WeatherNotifier();
    });

final mapHealthProvider = FutureProvider<MapHealthReport>((ref) async {
  final service = ref.watch(mapHealthServiceProvider);
  final settings = ref.watch(settingsProvider).value?['all'] ?? SettingsState();
  final customToken = settings.customMapboxToken;
  return await service.getHealthReport(customToken: customToken);
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
        final decrypted = KeyObfuscator.decrypt(jsonStr);
        return model.LocationSettings.fromJson(
          jsonDecode(decrypted) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('Error parsing/decrypting location settings: $e');
      }
    }
    return const model.LocationSettings();
  }

  Future<void> updateSettings(model.LocationSettings settings) async {
    state = AsyncData(settings);
    final storage = ref.read(storageServiceProvider);
    final encryptedData = KeyObfuscator.encrypt(jsonEncode(settings.toJson()));
    await storage.save(_filename, encryptedData);
  }

  Future<void> saveResolvedCity(String cityName, double lat, double lon) async {
    final current = state.value ?? const model.LocationSettings();
    if (current.lastCityName != cityName ||
        current.lastResolvedLatitude != lat ||
        current.lastResolvedLongitude != lon) {
      await updateSettings(
        current.copyWith(
          lastCityName: cityName,
          lastResolvedLatitude: lat,
          lastResolvedLongitude: lon,
        ),
      );
    }
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

Position getTimezoneFallbackCoordinates(tz.Location tzLocation) {
  final name = tzLocation.name;

  final knownMap = <String, (double, double)>{
    'Europe/Kyiv': (50.4547, 30.5238),
    'Europe/Kiev': (50.4547, 30.5238),
    'America/New_York': (40.7128, -74.0060),
    'America/Detroit': (42.3314, -83.0458),
    'America/Chicago': (41.8781, -87.6298),
    'America/Denver': (39.7392, -104.9903),
    'America/Los_Angeles': (34.0522, -118.2437),
    'America/Phoenix': (33.4484, -112.0740),
    'America/Anchorage': (61.2181, -149.9003),
    'Pacific/Honolulu': (21.3069, -157.8583),
    'Europe/London': (51.5074, -0.1278),
    'Europe/Paris': (48.8566, 2.3522),
    'Europe/Berlin': (52.5200, 13.4050),
    'Europe/Rome': (41.9028, 12.4964),
    'Europe/Madrid': (40.4168, -3.7038),
    'Europe/Warsaw': (52.2297, 21.0122),
    'Europe/Prague': (50.0755, 14.4378),
    'Europe/Bucharest': (44.4323, 26.1063),
    'Asia/Tokyo': (35.6762, 139.6503),
    'Asia/Shanghai': (31.2304, 121.4737),
    'Asia/Hong_Kong': (22.3193, 114.1694),
    'Asia/Singapore': (1.3521, 103.8198),
    'Asia/Bangkok': (13.7563, 100.5018),
    'Asia/Dubai': (25.2048, 55.2708),
    'Asia/Tashkent': (41.2995, 69.2401),
    'Asia/Almaty': (43.2220, 76.8512),
    'Australia/Sydney': (-33.8688, 151.2093),
    'Australia/Melbourne': (-37.8136, 144.9631),
    'America/Sao_Paulo': (-23.5505, -46.6333),
    'America/Buenos_Aires': (-34.6037, -58.3816),
    'Africa/Cairo': (30.0444, 31.2357),
    'Africa/Johannesburg': (-26.2041, 28.0473),
  };

  if (knownMap.containsKey(name)) {
    final (lat, lon) = knownMap[name]!;
    return Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  final now = tz.TZDateTime.now(tzLocation);
  final offsetHours = now.timeZoneOffset.inMinutes / 60.0;
  final approxLon = (offsetHours * 15.0).clamp(-180.0, 180.0);
  final approxLat =
      name.startsWith('Australia') ||
          name.startsWith('America/Argentina') ||
          name.startsWith('America/Sao_Paulo')
      ? -30.0
      : 45.0;

  return Position(
    latitude: approxLat,
    longitude: approxLon,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );
}

final effectiveLocationProvider = Provider<AsyncValue<Position>>((ref) {
  final resolutionStatus = ref.watch(locationResolutionStatusProvider);
  if (resolutionStatus == LocationResolutionStatus.autoFailedTimezone) {
    try {
      return AsyncData<Position>(getTimezoneFallbackCoordinates(tz.local));
    } catch (_) {
      return AsyncData<Position>(
        Position(
          latitude: 50.45,
          longitude: 30.52,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );
    }
  }

  final settingsVal = ref.watch(
    locationSettingsProvider.select((asyncVal) {
      final s = asyncVal.value;
      if (s == null) return null;
      return (s.useManual, s.manualLatitude, s.manualLongitude);
    }),
  );
  final streamAsync = ref.watch(locationStreamProvider);

  if (settingsVal != null) {
    final (useManual, manualLatitude, manualLongitude) = settingsVal;
    if (useManual && manualLatitude != null && manualLongitude != null) {
      return AsyncData<Position>(
        Position(
          latitude: manualLatitude,
          longitude: manualLongitude,
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
    // When auto-update is enabled, preserve previous coordinates during stream flickers
    final lastPos = streamAsync.value;
    if (lastPos != null) {
      return AsyncData<Position>(lastPos);
    }

    // If no prior data exists (e.g. first run), wait for stream data or fall back to timezone default
    return streamAsync.maybeWhen(
      data: (pos) => AsyncData<Position>(pos),
      orElse: () =>
          AsyncData<Position>(getTimezoneFallbackCoordinates(tz.local)),
    );
  }

  return AsyncData<Position>(getTimezoneFallbackCoordinates(tz.local));
});

enum LocationResolutionStatus { manual, autoSuccess, autoFailedTimezone }

final locationResolutionStatusProvider = Provider<LocationResolutionStatus>((
  ref,
) {
  final settingsAsync = ref.watch(locationSettingsProvider);
  final streamAsync = ref.watch(locationStreamProvider);

  final settings = settingsAsync.value;
  if (settings == null) return LocationResolutionStatus.autoFailedTimezone;

  if (settings.useManual) {
    if (settings.manualLatitude != null && settings.manualLongitude != null) {
      return LocationResolutionStatus.manual;
    }
    return LocationResolutionStatus.autoFailedTimezone;
  }

  if (streamAsync.hasValue && streamAsync.value != null) {
    return LocationResolutionStatus.autoSuccess;
  }

  return LocationResolutionStatus.autoFailedTimezone;
});

final geocodingServiceProvider = Provider((ref) => GeocodingService());

const _maxCityCacheDistanceDegrees = 0.01;

final locationCityProvider = FutureProvider<GeocodingResult>((ref) async {
  final resolutionStatus = ref.watch(locationResolutionStatusProvider);
  final locationAsync = ref.watch(effectiveLocationProvider);
  final locale = ref.watch(localeProvider);
  final settingsAsync = ref.watch(settingsProvider);
  final locationSettings = await ref.read(locationSettingsProvider.future);

  if (resolutionStatus == LocationResolutionStatus.autoFailedTimezone) {
    final timezoneVal = ref.watch(effectiveTimezoneProvider);
    return GeocodingResult(
      name: timezoneVal.name,
      isOffline: true,
      offlineReason: OfflineReason.apiError,
    );
  }

  final customToken = settingsAsync.maybeWhen(
    data: (map) => map['all']?.customMapboxToken,
    orElse: () => null,
  );

  return locationAsync.maybeWhen(
    data: (pos) async {
      final result = await ref
          .read(geocodingServiceProvider)
          .getCityName(
            pos.latitude,
            pos.longitude,
            language: locale.languageCode,
            customToken: customToken,
          );

      if (!result.isOffline) {
        unawaited(
          Future.microtask(() {
            ref
                .read(locationSettingsProvider.notifier)
                .saveResolvedCity(result.name, pos.latitude, pos.longitude);
          }),
        );
        return result;
      } else {
        if (locationSettings.lastCityName != null &&
            locationSettings.lastResolvedLatitude != null &&
            locationSettings.lastResolvedLongitude != null) {
          final latDiff =
              (pos.latitude - locationSettings.lastResolvedLatitude!).abs();
          final lonDiff =
              (pos.longitude - locationSettings.lastResolvedLongitude!).abs();

          if (latDiff < _maxCityCacheDistanceDegrees &&
              lonDiff < _maxCityCacheDistanceDegrees) {
            return GeocodingResult(
              name: locationSettings.lastCityName!,
              isOffline: true,
              offlineReason: result.offlineReason,
              isCachedCity: true,
            );
          }
        }
        return result;
      }
    },
    orElse: () => Future.value(
      const GeocodingResult(
        name: 'Global Coordinates',
        isOffline: true,
        offlineReason: OfflineReason.missingToken,
      ),
    ),
  );
});

final coordinatesAvailableProvider = Provider<bool>((ref) {
  final resolutionStatus = ref.watch(locationResolutionStatusProvider);
  return resolutionStatus != LocationResolutionStatus.autoFailedTimezone;
});

void _ensureTimeZonesInitialized() {
  try {
    tz.local;
  } catch (_) {
    try {
      tz_data.initializeTimeZones();
    } catch (_) {}
  }
}

final effectiveTimezoneProvider = Provider<tz.Location>((ref) {
  _ensureTimeZonesInitialized();

  tz.Location getSafeLocal() {
    try {
      return tz.local;
    } catch (_) {
      return tz.UTC;
    }
  }

  final locationAvailable = ref.watch(coordinatesAvailableProvider);
  if (!locationAvailable) {
    return getSafeLocal();
  }

  final locationAsync = ref.watch(effectiveLocationProvider);
  final pos = locationAsync.value;
  if (pos == null) {
    return getSafeLocal();
  }

  try {
    var tzName = tzmap.latLngToTimezoneString(pos.latitude, pos.longitude);
    if (tzName == 'Europe/Kiev') {
      tzName = 'Europe/Kyiv';
    }
    return tz.getLocation(tzName);
  } catch (e) {
    debugPrint(
      'Error looking up timezone for ${pos.latitude}, ${pos.longitude}: $e',
    );
    return getSafeLocal();
  }
});

final currentTimeProvider = StreamProvider<DateTime>((ref) async* {
  final visibility = ref.watch(appLifecycleProvider);
  final timezoneVal = ref.watch(effectiveTimezoneProvider);

  bool isDisposed = false;
  Timer? delayTimer;
  Completer<void>? activeCompleter;
  ref.onDispose(() {
    isDisposed = true;
    delayTimer?.cancel();
    final completer = activeCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  });

  // Adaptive delay for clock updates: 1s if visible, 1m if hidden
  final delay = visibility == AppVisibilityState.visible
      ? const Duration(seconds: 1)
      : const Duration(minutes: 1);

  while (!isDisposed) {
    yield tz.TZDateTime.now(timezoneVal);
    final completer = Completer<void>();
    activeCompleter = completer;
    delayTimer = Timer(delay, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;
  }
});

/// Provider that emits the current solar state.
/// The frequency of updates is adaptive based on the app's visibility state:
/// - Visible: 1 second
/// - Minimized: 30 seconds
/// - Hidden (Tray): 60 seconds
final solarStateStreamProvider = StreamProvider<SolarState>((ref) async* {
  bool isDisposed = false;
  Timer? delayTimer;
  Completer<void>? activeCompleter;
  ref.onDispose(() {
    isDisposed = true;
    delayTimer?.cancel();
    final completer = activeCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  });

  Future<void> cancellableDelay(int seconds) {
    if (isDisposed) return Future.value();
    final completer = Completer<void>();
    activeCompleter = completer;
    delayTimer = Timer(Duration(seconds: seconds), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  final service = ref.watch(sunCalculatorServiceProvider);
  final locationAsync = ref.watch(effectiveLocationProvider);
  // Keep weather current without restarting the astronomical ticker on each
  // weather refresh. Weather affects radiation estimates, not the sun's orbit.
  var weatherAsync = ref.read(currentWeatherProvider);
  ref.listen(currentWeatherProvider, (_, next) => weatherAsync = next);
  final visibility = ref.watch(appLifecycleProvider);
  final timezoneVal = ref.watch(effectiveTimezoneProvider);

  // Use location from provider, or default to Kyiv if loading
  final pos = locationAsync.value;
  final lat = pos?.latitude ?? 50.45;
  final lon = pos?.longitude ?? 30.52;

  final initialNow = tz.TZDateTime.now(timezoneVal);

  // Initial calculation
  SolarPhaseModel phases = await service.calculatePhases(
    lat,
    lon,
    initialNow,
    timezoneVal,
  );
  double maxElevation = service.getSunElevation(lat, lon, phases.solarNoon);
  final nadirTime = phases.solarNoon.add(const Duration(hours: 12));
  double minElevation = service.getSunElevation(lat, lon, nadirTime);

  // Previous values for trend calculation
  double? prevAzimuth;
  double? prevElevation;
  double? prevZenith;
  DateTime? prevTime;

  // Adaptive delay based on visibility
  final delaySeconds = switch (visibility) {
    AppVisibilityState.visible => 1,
    AppVisibilityState.minimized => 30,
    AppVisibilityState.hidden => 60,
  };

  // Immediate rough calculation to avoid "sun flash" at startup
  final roughElevation = service.getSunElevation(lat, lon, initialNow);
  final roughAzimuth = service.getSunAzimuth(lat, lon, initialNow);
  final roughProgress = service.getSunProgress(phases, initialNow);
  final nextEvent = service.getNextEvent(phases, initialNow);

  if (nextEvent != null) {
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
      azimuthTrend: 'constant',
      elevationTrend: 'constant',
      zenithTrend: 'constant',
      maxElevation: maxElevation,
      minElevation: minElevation,
    );
  } else {
    ref
        .read(logServiceProvider)
        .logWarning(
          'SolarState: exhausted phase timeline at $initialNow; retrying on the next tick',
        );
  }

  // In test environments, avoid scheduling an infinite live-ticker timer
  // that would remain pending in FakeAsync after widget disposal.
  if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
    return;
  }

  while (!isDisposed) {
    final now = tz.TZDateTime.now(timezoneVal);

    // Compare the full local date, including jumps to the same day of another month.
    if (!phases.isForDate(now)) {
      phases = await service.calculatePhases(lat, lon, now, timezoneVal);
      maxElevation = service.getSunElevation(lat, lon, phases.solarNoon);
      final nextNadir = phases.solarNoon.add(const Duration(hours: 12));
      minElevation = service.getSunElevation(lat, lon, nextNadir);
    }

    // When hidden to tray, skip expensive trend/UV/spectral calculations.
    // Only compute fields needed by circadianAdjustmentProvider:
    // sunElevation, currentPhase, phases, sunProgress, nextEvent.
    // This reduces heap allocations and GC pressure by ~2-5 MB.
    if (visibility == AppVisibilityState.hidden) {
      final elevation = service.getSunElevation(lat, lon, now);
      final progress = service.getSunProgress(phases, now);
      final nextEvt = service.getNextEvent(phases, now);
      final phase = service.getCurrentPhase(phases, now);

      if (nextEvt != null) {
        yield SolarState(
          sunElevation: elevation,
          sunAzimuth: prevAzimuth ?? 0,
          sunZenith: prevZenith ?? 90,
          sunProgress: progress,
          currentPhase: phase,
          nextEventType: nextEvt.type,
          timeUntilNextEvent: nextEvt.duration,
          phases: phases,
          uvIndex: 0,
          spectralIntensity: 0,
          elevationTrend: 'constant',
          azimuthTrend: 'constant',
          zenithTrend: 'constant',
          maxElevation: maxElevation,
          minElevation: minElevation,
        );
      } else {
        ref
            .read(logServiceProvider)
            .logWarning(
              'SolarState: exhausted phase timeline at $now; retrying on the next tick',
            );
      }

      prevElevation = elevation;
      prevTime = now;

      await cancellableDelay(delaySeconds);
      continue;
    }

    final currentElevation = service.getSunElevation(lat, lon, now);
    final currentAzimuth = service.getSunAzimuth(lat, lon, now);
    final currentZenith = service.getSunZenith(lat, lon, now);

    double? timeDiffSeconds;
    if (prevTime != null) {
      timeDiffSeconds = now.difference(prevTime).inMilliseconds / 1000.0;
    }

    String azTrend = 'constant';
    if (prevAzimuth != null && timeDiffSeconds != null && timeDiffSeconds > 0) {
      double diff = currentAzimuth - prevAzimuth;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;

      final degPerHour = (diff / timeDiffSeconds) * 3600;
      if (degPerHour.abs() > 0.1) {
        azTrend = degPerHour > 0
            ? '+${degPerHour.toStringAsFixed(1)}°/h'
            : '${degPerHour.toStringAsFixed(1)}°/h';
      }
    }

    String elTrend = 'constant';
    if (prevElevation != null &&
        timeDiffSeconds != null &&
        timeDiffSeconds > 0) {
      final diff = currentElevation - prevElevation;
      final degPerHour = (diff / timeDiffSeconds) * 3600;
      if (degPerHour.abs() > 0.1) {
        elTrend = degPerHour > 0
            ? '+${degPerHour.toStringAsFixed(1)}°/h'
            : '${degPerHour.toStringAsFixed(1)}°/h';
      }
    }

    String zenTrend = 'constant';
    if (prevZenith != null && timeDiffSeconds != null && timeDiffSeconds > 0) {
      final diff = currentZenith - prevZenith;
      final degPerHour = (diff / timeDiffSeconds) * 3600;
      if (degPerHour.abs() > 0.1) {
        zenTrend = degPerHour > 0
            ? '+${degPerHour.toStringAsFixed(1)}°/h'
            : '${degPerHour.toStringAsFixed(1)}°/h';
      }
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

    if (nextEvent != null) {
      yield SolarState(
        phases: phases,
        currentPhase: service.getCurrentPhase(phases, now),
        timeUntilNextEvent: nextEvent.duration,
        nextEventType: nextEvent.type,
        sunElevation: currentElevation,
        sunAzimuth: currentAzimuth,
        sunZenith: currentZenith,
        sunProgress: service.getSunProgress(phases, now),
        uvIndex: uv,
        spectralIntensity: intensity,
        azimuthTrend: azTrend,
        elevationTrend: elTrend,
        zenithTrend: zenTrend,
        maxElevation: maxElevation,
        minElevation: minElevation,
      );
    } else {
      ref
          .read(logServiceProvider)
          .logWarning(
            'SolarState: exhausted phase timeline at $now; retrying on the next tick',
          );
    }

    prevAzimuth = currentAzimuth;
    prevElevation = currentElevation;
    prevZenith = currentZenith;
    prevTime = now;

    await cancellableDelay(delaySeconds);
  }
});

// solarDataProvider logic unified into solarStateStreamProvider

/// A debounced view of [solarStateStreamProvider] for the hardware-facing
/// circadian loop. The raw stream emits once per second (when visible) so the
/// on-screen chart stays smooth, but the Bezier math + weather adjustment +
/// gaming override cascade inside [circadianAdjustmentProvider] does not need
/// to run that often — sun elevation moves very slowly.
///
/// This provider only forwards a new state when one of:
///   * sun elevation moved >= 0.1 degrees since the last forwarded value
///   * the current day phase changed (sunrise / golden hour / twilight / ...)
///   * 60 seconds passed since the last forwarded value (safety heartbeat)
class _DebouncedSolarStateNotifier extends Notifier<AsyncValue<SolarState>> {
  double? _lastElevation;
  DateTime? _lastEmitTime;
  CurrentDayPhase? _lastPhase;

  @override
  AsyncValue<SolarState> build() {
    ref.listen<AsyncValue<SolarState>>(solarStateStreamProvider, (prev, next) {
      if (next is AsyncError) {
        state = next;
        return;
      }
      next.whenData((solar) {
        final now = DateTime.now();
        final phaseChanged = _lastPhase != solar.currentPhase;
        final elevDelta = _lastElevation == null
            ? double.infinity
            : (solar.sunElevation - _lastElevation!).abs();
        final heartbeat =
            _lastEmitTime == null ||
            now.difference(_lastEmitTime!).inSeconds >= 60;

        if (!state.hasValue || phaseChanged || elevDelta >= 0.1 || heartbeat) {
          _lastElevation = solar.sunElevation;
          _lastPhase = solar.currentPhase;
          _lastEmitTime = now;
          state = AsyncValue.data(solar);
        }
      });
    }, fireImmediately: true);

    final initial = ref.read(solarStateStreamProvider);
    if (initial.hasValue) {
      _lastElevation = initial.value!.sunElevation;
      _lastPhase = initial.value!.currentPhase;
      _lastEmitTime = DateTime.now();
      return initial;
    }
    return const AsyncValue.loading();
  }
}

final debouncedSolarStateProvider =
    NotifierProvider<_DebouncedSolarStateNotifier, AsyncValue<SolarState>>(
      _DebouncedSolarStateNotifier.new,
    );

class MonitorListNotifier extends AsyncNotifier<List<MonitorInfo>> {
  @override
  Future<List<MonitorInfo>> build() async {
    ref.listen<AppVisibilityState>(appLifecycleProvider, (prev, next) async {
      if (prev != AppVisibilityState.visible &&
          next == AppVisibilityState.visible) {
        final newMonitors = await ref
            .read(monitorServiceProvider)
            .getConnectedMonitors();
        if (!ref.mounted || next != ref.read(appLifecycleProvider)) return;
        final bService = ref.read(brightnessServiceProvider);
        final tService = ref.read(temperatureServiceProvider);

        // Preserve active software dimming state if hardware reports minimum brightness floor (0-5%)
        final previousMonitors = state.value ?? [];
        final updatedMonitors = newMonitors.map((m) {
          int? effectiveBrightness = m.realBrightness;
          if (effectiveBrightness != null &&
              effectiveBrightness >= 0 &&
              effectiveBrightness <=
                  MonitorService.hardwareBrightnessFloorThreshold) {
            final prev = previousMonitors
                .where((p) => p.deviceName == m.deviceName)
                .firstOrNull;
            final prevBrightness = prev?.realBrightness;
            if (prevBrightness != null && prevBrightness < 0) {
              effectiveBrightness = prevBrightness;
            }
          }
          if (effectiveBrightness != m.realBrightness) {
            return m.copyWith(realBrightness: effectiveBrightness);
          }
          return m;
        }).toList();

        for (final m in updatedMonitors) {
          if (m.realBrightness != null) {
            bService.syncHardwareBrightness(m.deviceName, m.realBrightness!);
          }
          if (m.realTemperature != null) {
            tService.syncHardwareTemperature(m.deviceName, m.realTemperature!);
          }
        }
        if (state.hasValue) {
          state = AsyncData(updatedMonitors);
          ref.read(manualBrightnessApplierProvider)(selection: {'all'});
        }
      }
    });

    return ref.watch(monitorServiceProvider).getConnectedMonitors();
  }

  void updateBrightness(String deviceName, int brightness) {
    _updateMonitor(deviceName, brightness, null);
  }

  void updateTemperature(String deviceName, int temperature) {
    _updateMonitor(deviceName, null, temperature);
  }

  void _updateMonitor(String deviceName, int? brightness, int? temperature) {
    if (!ref.mounted) return;
    state.whenData((monitors) {
      bool changed = false;
      final newList = monitors.map((m) {
        if (m.deviceName == deviceName) {
          final newBrightness = brightness ?? m.realBrightness;
          final newTemperature = temperature ?? m.realTemperature;
          if (newBrightness != m.realBrightness ||
              newTemperature != m.realTemperature) {
            changed = true;
            return m.copyWith(
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

/// Provider that tracks the connected monitor device names.
/// Only emits when displays are physically connected, disconnected, or re-enumerated,
/// preventing transition loop feedback cycles when realBrightness/realTemperature changes.
final connectedMonitorDevicesProvider = Provider<String>((ref) {
  final monitorsAsync = ref.watch(monitorListProvider);
  final monitors = monitorsAsync.value ?? [];
  final names = monitors.map((m) => m.deviceName).toList()..sort();
  return names.join(';');
});

/// Provider for the monitor(s) currently being edited or controlled.
/// Default is {'all'}.
class SelectedMonitorsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {'all'};

  void toggle(String id) {
    if (id == 'all') {
      state = {'all'};
      _syncAll();
      debugPrint('[MonitorSelection] Active monitors changed: $state');
      return;
    }
    final newState = Set<String>.from(state);
    newState.remove('all');
    if (newState.contains(id)) {
      newState.remove(id);
    } else {
      newState.add(id);
    }
    if (newState.isEmpty) {
      state = {'all'};
      _syncAll();
    } else {
      state = newState;
    }
    debugPrint('[MonitorSelection] Active monitors changed: $state');
  }

  void selectOnly(String id) {
    state = {id};
    if (id == 'all') {
      _syncAll();
    }
    debugPrint('[MonitorSelection] Active monitors changed: $state');
  }

  void _syncAll() {
    ref.read(settingsProvider.notifier).syncAllMonitorsToGlobal();
    ref.read(temperatureSettingsProvider.notifier).syncAllMonitorsToGlobal();
  }
}

final selectedMonitorsProvider =
    NotifierProvider<SelectedMonitorsNotifier, Set<String>>(
      SelectedMonitorsNotifier.new,
    );

enum AppScreen { dashboard, schedule, sleep, settings, location, appOverrides }

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
    if (languageCode != 'en' && languageCode != 'ru' && languageCode != 'uk') {
      return;
    }
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
    if (state == value) {
      if (!value) ref.read(manualBrightnessApplierProvider)();
      return;
    }
    state = value;
    ref
        .read(sharedPreferencesProvider)
        ?.setBool(_autoBrightnessEnabledKey, value);
    if (value) {
      ref.read(brightnessServiceProvider).invalidateCache();
    }
    ref.read(settingsProvider.notifier).updateAutoBrightness(value);
  }

  void toggle() {
    setEnabled(!state);
  }
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
    final newState = !state;
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

  void update(double value, {Set<String>? selection}) {
    if (!value.isFinite) return;
    state = value;
    ref.read(sharedPreferencesProvider)?.setDouble(_manualBrightnessKey, value);
    ref.read(manualBrightnessApplierProvider)(
      selection: selection,
      targetValue: value,
    );
  }
}

final manualBrightnessProvider =
    NotifierProvider<ManualBrightnessNotifier, double>(
      ManualBrightnessNotifier.new,
    );

enum SettingsEncryptionError { passwordChanged, invalidData, generic }

class SettingsErrorNotifier extends Notifier<SettingsEncryptionError?> {
  @override
  SettingsEncryptionError? build() => null;

  @override
  set state(SettingsEncryptionError? value) => super.state = value;
}

final settingsErrorProvider =
    NotifierProvider<SettingsErrorNotifier, SettingsEncryptionError?>(
      SettingsErrorNotifier.new,
    );

// SettingsState moved to lib/models/settings_state.dart

class SettingsNotifier extends AsyncNotifier<Map<String, SettingsState>> {
  static const _settingsFilename = 'monitor_settings.json';
  Timer? _saveTimer;
  final Map<String, DateTime> _lastTouchCache = {};

  @override
  Future<Map<String, SettingsState>> build() async {
    final storage = ref.watch(storageServiceProvider);
    final settings = await _loadSettings(storage);

    // Load startup mode from SharedPreferences
    final prefs = ref.read(sharedPreferencesProvider);
    final savedModeStr = prefs?.getString('startup_mode');
    final StartupMode startupMode;
    if (savedModeStr != null) {
      startupMode = StartupMode.values.firstWhere(
        (e) => e.name == savedModeStr,
        orElse: () => StartupMode.minimized,
      );
      if (settings['all'] != null) {
        settings['all'] = settings['all']!.copyWith(startupMode: startupMode);
      }
    } else {
      startupMode = settings['all']?.startupMode ?? StartupMode.minimized;
    }

    // Sync autorun on startup
    final isEnabled = settings['all']?.isAutorunEnabled ?? true;
    unawaited(AutorunService.setEnabled(isEnabled, startupMode));

    return settings;
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
          try {
            map[key] = SettingsState.fromJson(value as Map<String, dynamic>);
          } on DpapiPasswordChangedException catch (e) {
            debugPrint('DPAPI Password Changed: $e');
            Future.microtask(() {
              ref.read(settingsErrorProvider.notifier).state =
                  SettingsEncryptionError.passwordChanged;
            });
            // Clean credentials and parse the rest of settings to preserve user presets
            final cleanedValue = Map<String, dynamic>.from(value as Map);
            cleanedValue['customWeatherApiKey'] = '';
            cleanedValue['customMapboxToken'] = '';
            cleanedValue['customGoogleClientId'] = '';
            cleanedValue['customGoogleClientSecret'] = '';
            map[key] = SettingsState.fromJson(cleanedValue);
          } on DpapiInvalidDataException catch (e) {
            debugPrint('DPAPI Invalid Data: $e');
            Future.microtask(() {
              ref.read(settingsErrorProvider.notifier).state =
                  SettingsEncryptionError.invalidData;
            });
            final cleanedValue = Map<String, dynamic>.from(value as Map);
            cleanedValue['customWeatherApiKey'] = '';
            cleanedValue['customMapboxToken'] = '';
            cleanedValue['customGoogleClientId'] = '';
            cleanedValue['customGoogleClientSecret'] = '';
            map[key] = SettingsState.fromJson(cleanedValue);
          } on DpapiGenericException catch (e) {
            debugPrint('DPAPI Generic Error: $e');
            Future.microtask(() {
              ref.read(settingsErrorProvider.notifier).state =
                  SettingsEncryptionError.generic;
            });
            final cleanedValue = Map<String, dynamic>.from(value as Map);
            cleanedValue['customWeatherApiKey'] = '';
            cleanedValue['customMapboxToken'] = '';
            cleanedValue['customGoogleClientId'] = '';
            cleanedValue['customGoogleClientSecret'] = '';
            map[key] = SettingsState.fromJson(cleanedValue);
          } catch (e) {
            debugPrint('Error parsing settings state for key $key: $e');
          }
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
      if (!ref.mounted) return;
      state.whenData((currentMap) async {
        if (!ref.mounted) return;
        final storage = ref.read(storageServiceProvider);
        final encoded = currentMap.map(
          (key, value) => MapEntry(key, value.toJson()),
        );
        await storage.save(_settingsFilename, jsonEncode(encoded));
      });
    });
  }

  Future<void> savePendingSettings() async {
    if (_saveTimer != null && _saveTimer!.isActive) {
      _saveTimer!.cancel();
      final currentMap = state.value;
      if (currentMap != null) {
        final storage = ref.read(storageServiceProvider);
        final encoded = currentMap.map(
          (key, value) => MapEntry(key, value.toJson()),
        );
        await storage.save(_settingsFilename, jsonEncode(encoded));
      }
    }
  }

  SettingsState _getSettings(String monitorId) {
    final currentMap = state.value ?? {'all': SettingsState()};
    return currentMap[monitorId] ?? currentMap['all']!;
  }

  void _updateSettings(
    Set<String> monitorIds,
    SettingsState Function(SettingsState) transform,
  ) {
    final currentMap = state.value ?? {'all': SettingsState()};
    final newStateMap = Map<String, SettingsState>.from(currentMap);

    for (final id in monitorIds) {
      if (id == 'all') {
        newStateMap['all'] = transform(newStateMap['all'] ?? SettingsState());
        // Replicate CHANGE to all other specific monitors without overwriting their unique fields
        for (final key in newStateMap.keys.toList()) {
          if (key != 'all') {
            newStateMap[key] = transform(newStateMap[key]!);
          }
        }
      } else {
        final current =
            newStateMap[id] ?? newStateMap['all'] ?? SettingsState();
        newStateMap[id] = transform(current);
      }
    }

    if (const MapEquality<String, SettingsState>().equals(
      currentMap,
      newStateMap,
    )) {
      return;
    }

    debugPrint('[SettingsNotifier] Updated settings for monitors $monitorIds');
    state = AsyncData(newStateMap);
    _saveSettings();
  }

  void syncAllMonitorsToGlobal() {
    final currentMap = state.value ?? {'all': SettingsState()};
    final global = currentMap['all'] ?? SettingsState();
    final newStateMap = Map<String, SettingsState>.from(currentMap);

    for (final key in newStateMap.keys.toList()) {
      if (key != 'all') {
        newStateMap[key] = newStateMap[key]!.copyWith(
          activePreset: global.activePreset,
          activeUserPresetId: global.activeUserPresetId,
          clearActiveUserPresetId: global.activeUserPresetId == null,
          curvesMap: global.curvesMap,
          userPresets: global.userPresets,
          circadianMode: global.circadianMode,
          phasesConfig: global.phasesConfig,
        );
      }
    }

    debugPrint(
      '[SettingsNotifier] Synchronized all monitor presets with global preset (${global.activePreset.name})',
    );
    state = AsyncData(newStateMap);
    _saveSettings();
  }

  void updateCurveSharpness(double value) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(curveSharpness: value),
    );
  }

  void updateCircadianMode(CircadianMode mode) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(circadianMode: mode),
    );
  }

  void updatePhasesConfig(SolarPhasesConfig config) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(phasesConfig: config),
    );
  }

  void updateAutorun(bool enabled) {
    _updateSettings(
      {'all'}, // Autorun is globally replicated
      (s) => s.copyWith(isAutorunEnabled: enabled),
    );
    final startupMode = _getSettings('all').startupMode;
    AutorunService.setEnabled(enabled, startupMode);
  }

  void updateAutoUpdateEnabled(bool enabled) {
    _updateSettings(
      {'all'}, // AutoUpdate is globally replicated
      (s) => s.copyWith(isAutoUpdateEnabled: enabled),
    );
  }

  void updateStartupMode(StartupMode mode) {
    ref.read(sharedPreferencesProvider)?.setString('startup_mode', mode.name);
    _updateSettings({'all'}, (s) => s.copyWith(startupMode: mode));
    final isEnabled = _getSettings('all').isAutorunEnabled;
    AutorunService.setEnabled(isEnabled, mode);
  }

  void updateSoftwareDimming(bool enabled) {
    _updateSettings({
      'all',
    }, (s) => s.copyWith(isSoftwareDimmingEnabled: enabled));
    if (!enabled) {
      final currentManual = ref.read(manualBrightnessProvider);
      if (currentManual < 0) {
        ref.read(manualBrightnessProvider.notifier).update(0.0);
        ref.read(currentBrightnessProvider.notifier).setManualBrightness(0.0);
      }
    }
  }

  void updateWeatherAdjustment(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isWeatherAdjustmentEnabled: enabled),
    );
  }

  void updateWeatherTemperatureAdjustment(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isWeatherTemperatureAdjustmentEnabled: enabled),
    );
  }

  void updateWeatherAdjustmentIntensity(double intensity) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(weatherAdjustmentIntensity: intensity),
    );
  }

  void updateApiPermissions(ApiPermissionsConfig config) {
    _updateSettings({'all'}, (s) {
      final currentKeys = List<ApiKeyEntry>.from(s.apiKeys);
      if (currentKeys.isNotEmpty) {
        currentKeys[0] = currentKeys.first.copyWith(permissions: config);
      }
      return s.copyWith(apiPermissions: config, apiKeys: currentKeys);
    });
  }

  void updateWeatherProvider(WeatherProvider provider) {
    _updateSettings(
      {'all'}, // Weather provider is likely intended to be global
      (s) => s.copyWith(weatherProvider: provider),
    );
  }

  void updateCustomWeatherApiKey(String value) {
    _updateSettings({'all'}, (s) => s.copyWith(customWeatherApiKey: value));
  }

  // Per-App Overrides Management
  void addAppOverride(AppOverrideRule rule) {
    final sanitizedRule = rule.copyWith(exeName: rule.exeName);
    final lower = sanitizedRule.exeName;
    _updateSettings({'all'}, (s) {
      final existing = s.appOverrides
          .where((r) => r.exeName.toLowerCase() != lower)
          .toList();
      return s.copyWith(appOverrides: [...existing, sanitizedRule]);
    });
  }

  void updateAppOverride(AppOverrideRule rule) {
    final sanitizedRule = rule.copyWith(exeName: rule.exeName);
    final lower = sanitizedRule.exeName;
    _updateSettings({'all'}, (s) {
      final list = s.appOverrides
          .map((r) => r.exeName.toLowerCase() == lower ? sanitizedRule : r)
          .toList();
      return s.copyWith(appOverrides: list);
    });
  }

  void removeAppOverride(String exeName) {
    final lower = exeName.trim().toLowerCase();
    _updateSettings({'all'}, (s) {
      final list = s.appOverrides.where((r) => r.exeName != lower).toList();
      return s.copyWith(appOverrides: list);
    });
  }

  void toggleAppOverride(String exeName, bool enabled) {
    final lower = exeName.trim().toLowerCase();
    _updateSettings({'all'}, (s) {
      final list = s.appOverrides.map((r) {
        if (r.exeName == lower) {
          return r.copyWith(isEnabled: enabled);
        }
        return r;
      }).toList();
      return s.copyWith(appOverrides: list);
    });
  }

  void resetBuiltInAppOverrides() {
    _updateSettings({'all'}, (s) {
      final userRules = s.appOverrides.where((r) => !r.isBuiltIn).toList();
      final userExeNames = userRules.map((r) => r.exeName).toSet();
      final defaultBuiltInsToAdd = AppOverrideRule.defaultBuiltInRules
          .where((r) => !userExeNames.contains(r.exeName))
          .toList();
      return s.copyWith(appOverrides: [...userRules, ...defaultBuiltInsToAdd]);
    });
  }

  void promoteBuiltInToUser(String exeName) {
    final lower = exeName.trim().toLowerCase();
    _updateSettings({'all'}, (s) {
      final list = s.appOverrides.map((r) {
        if (r.exeName == lower && r.isBuiltIn) {
          return r.copyWith(isBuiltIn: false);
        }
        return r;
      }).toList();
      return s.copyWith(appOverrides: list);
    });
  }

  void updateAppOverrideExitDelay(int seconds) {
    final clamped = seconds.clamp(0, 300);
    _updateSettings({
      'all',
    }, (s) => s.copyWith(appOverrideExitDelaySeconds: clamped));
  }

  void updateCustomMapboxToken(String value) {
    _updateSettings({'all'}, (s) => s.copyWith(customMapboxToken: value));
  }

  void updateCustomGoogleClientId(String value) {
    _updateSettings({'all'}, (s) => s.copyWith(customGoogleClientId: value));
  }

  void updateCustomGoogleClientSecret(String value) {
    _updateSettings({
      'all',
    }, (s) => s.copyWith(customGoogleClientSecret: value));
  }

  void updateGameModeEnabled(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isGameModeEnabled: enabled),
    );
  }

  void updateMonitorGameModeEnabled(String monitorDeviceName, bool enabled) {
    final currentMap = state.value ?? {'all': SettingsState()};
    final newStateMap = Map<String, SettingsState>.from(currentMap);
    final current =
        newStateMap[monitorDeviceName] ?? newStateMap['all'] ?? SettingsState();
    newStateMap[monitorDeviceName] = current.copyWith(
      isGameModeEnabled: enabled,
    );
    debugPrint(
      '[SettingsNotifier] Updated game mode for monitor $monitorDeviceName to $enabled',
    );
    state = AsyncData(newStateMap);
    _saveSettings();
  }

  void setGameModeScope({
    required bool primaryOnly,
    required List<MonitorInfo> monitors,
  }) {
    final currentMap = state.value ?? {'all': SettingsState()};
    final newStateMap = Map<String, SettingsState>.from(currentMap);
    final global = newStateMap['all'] ?? SettingsState();
    newStateMap['all'] = global.copyWith(isGameModeEnabled: true);

    for (final monitor in monitors) {
      final current = newStateMap[monitor.deviceName] ?? global;
      final shouldEnable = primaryOnly ? monitor.isPrimary : true;
      newStateMap[monitor.deviceName] = current.copyWith(
        isGameModeEnabled: shouldEnable,
      );
    }
    debugPrint(
      '[SettingsNotifier] Set game mode scope (primaryOnly: $primaryOnly) across ${monitors.length} monitors',
    );
    state = AsyncData(newStateMap);
    _saveSettings();
  }

  void updateGameModeBrightness(double brightness) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(gameModeBrightness: brightness),
    );
  }

  void updateGameModeTemperatureEnabled(bool enabled) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(isGameModeTemperatureEnabled: enabled),
    );
  }

  void updateGameModeTemperature(double temperature) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(gameModeTemperature: temperature),
    );
  }

  void updateGameModeExitDelaySeconds(int seconds) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(gameModeExitDelaySeconds: seconds),
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

  void updateAutoBrightness(bool enabled, {String? monitorId}) {
    final ids = monitorId == null
        ? ref.read(selectedMonitorsProvider)
        : {monitorId};
    ref
        .read(sharedPreferencesProvider)
        ?.setBool('auto_brightness_enabled', enabled);
    _updateSettings(ids, (s) => s.copyWith(isAutoBrightnessEnabled: enabled));
    if (!enabled) {
      ref.read(manualBrightnessApplierProvider)(selection: ids);
    }
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

  void updateLocalIpcServerEnabled(bool enabled) {
    _updateSettings({
      'all',
    }, (s) => s.copyWith(isLocalIpcServerEnabled: enabled));
  }

  void updateApiServerEnabled(bool enabled) {
    _updateSettings({'all'}, (s) => s.copyWith(isApiServerEnabled: enabled));
  }

  void updateSleepIpcServerEnabled(bool enabled) {
    _updateSettings({
      'all',
    }, (s) => s.copyWith(isSleepIpcServerEnabled: enabled));
  }

  void updateLocalIpcServerPort(int port) {
    _updateSettings({
      'all',
    }, (s) => s.copyWith(localIpcServerPort: port, apiServerPort: port));
  }

  void updateApiServerPort(int port) {
    _updateSettings({
      'all',
    }, (s) => s.copyWith(apiServerPort: port, localIpcServerPort: port));
  }

  void updateApiLanAccessEnabled(bool enabled) {
    _updateSettings({'all'}, (s) => s.copyWith(isApiLanAccessEnabled: enabled));
  }

  void updateApiAccessToken(String token) {
    _updateSettings({'all'}, (s) => s.copyWith(apiAccessToken: token));
  }

  void updateRequireLocalToken(bool enabled) {
    _updateSettings({'all'}, (s) => s.copyWith(requireLocalToken: enabled));
  }

  void addApiKey(ApiKeyEntry entry) {
    _updateSettings({'all'}, (s) {
      final currentKeys = List<ApiKeyEntry>.from(s.apiKeys)..add(entry);
      return s.copyWith(apiKeys: currentKeys);
    });
  }

  void updateApiKey(ApiKeyEntry entry) {
    _updateSettings({'all'}, (s) {
      final currentKeys = List<ApiKeyEntry>.from(s.apiKeys);
      final index = currentKeys.indexWhere((k) => k.id == entry.id);
      if (index != -1) {
        currentKeys[index] = entry;
      }
      return s.copyWith(apiKeys: currentKeys);
    });
  }

  bool removeApiKey(String id) {
    final globalState = state.value?['all'] ?? SettingsState();
    if (globalState.apiKeys.length <= 1) {
      debugPrint('SettingsNotifier: Cannot remove the sole remaining API key.');
      return false; // Guard triggered: prohibit deleting the last remaining key
    }
    final currentKeys = globalState.apiKeys.where((k) => k.id != id).toList();
    _lastTouchCache.remove(id);
    _updateSettings({'all'}, (s) => s.copyWith(apiKeys: currentKeys));
    return true;
  }

  String regenerateApiKeyToken(String id) {
    final globalState = state.value?['all'] ?? SettingsState();
    final currentKeys = List<ApiKeyEntry>.from(globalState.apiKeys);
    final index = currentKeys.indexWhere((k) => k.id == id);
    if (index != -1) {
      final newToken = ApiKeyEntry.generateSecureToken();
      currentKeys[index] = currentKeys[index].copyWith(token: newToken);
      _lastTouchCache.remove(id);
      _updateSettings({'all'}, (s) => s.copyWith(apiKeys: currentKeys));
      return newToken;
    }
    return '';
  }

  void touchApiKeyLastUsed(String id) {
    if (!ref.mounted) return;
    final now = DateTime.now();
    final lastTouch = _lastTouchCache[id];
    if (lastTouch == null || now.difference(lastTouch).inMinutes >= 5) {
      _lastTouchCache[id] = now;
      final globalState = state.value?['all'] ?? SettingsState();
      final currentKeys = List<ApiKeyEntry>.from(globalState.apiKeys);
      final index = currentKeys.indexWhere((k) => k.id == id);
      if (index != -1) {
        currentKeys[index] = currentKeys[index].copyWith(lastUsedAt: now);
        if (ref.mounted) {
          _updateSettings({'all'}, (s) => s.copyWith(apiKeys: currentKeys));
        }
      }
    }
  }

  void dismissDpapiFallbackWarning(String id) {
    final globalState = state.value?['all'] ?? SettingsState();
    final currentKeys = List<ApiKeyEntry>.from(globalState.apiKeys);
    final index = currentKeys.indexWhere((k) => k.id == id);
    if (index != -1 && currentKeys[index].isDpapiFallback) {
      currentKeys[index] = currentKeys[index].copyWith(isDpapiFallback: false);
      _updateSettings({'all'}, (s) => s.copyWith(apiKeys: currentKeys));
    }
  }

  void updateApiRateLimitPerMinute(int rateLimit) {
    _updateSettings({
      'all',
    }, (s) => s.copyWith(apiRateLimitPerMinute: rateLimit));
  }

  void setWebhooks(List<WebhookConfig> webhooks) {
    _updateSettings({'all'}, (s) => s.copyWith(webhooks: webhooks));
  }

  void addWebhook(WebhookConfig config) {
    _updateSettings({'all'}, (s) {
      final updated = List<WebhookConfig>.from(s.webhooks)..add(config);
      return s.copyWith(webhooks: updated);
    });
  }

  void updateWebhook(WebhookConfig config) {
    _updateSettings({'all'}, (s) {
      final updated = s.webhooks
          .map((w) => w.id == config.id ? config : w)
          .toList();
      return s.copyWith(webhooks: updated);
    });
  }

  void deleteWebhook(String id) {
    _updateSettings({'all'}, (s) {
      final updated = s.webhooks.where((w) => w.id != id).toList();
      return s.copyWith(webhooks: updated);
    });
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

  void updateSleepVisibleSessionsCount(int value) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(sleepVisibleSessionsCount: value.clamp(1, 50)),
    );
  }

  void updateTimeShiftIntensity(double brightness, double temperature) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(
        timeShiftBrightnessIntensity: brightness,
        timeShiftIntensity: brightness,
        timeShiftTemperatureIntensity: temperature,
      ),
    );
  }

  void updateSleepPressureIntensity(double brightness, double temperature) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(
        sleepPressureBrightnessIntensity: brightness,
        sleepPressureTemperatureIntensity: temperature,
      ),
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
        if (s.curvePoints[index].x == -20 || s.curvePoints[index].x == 90) {
          return s;
        }
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
      (s) => s.copyWith(
        activePreset: type,
        clearActiveUserPresetId: true,
        isAutoBrightnessEnabled: true,
      ),
    );
  }

  void updateMultiMonitorOffsetEnabled(bool enabled) {
    _updateSettings({
      'all',
    }, (s) => s.copyWith(isMultiMonitorOffsetEnabled: enabled));
  }

  void updateMonitorOffset(String monitorId, double offset) {
    _updateSettings({monitorId}, (s) => s.copyWith(brightnessOffset: offset));
  }

  void setActiveUserPreset(String id) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(activeUserPresetId: id, isAutoBrightnessEnabled: true),
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
      final newPresetOrder = s.presetOrder
          .where((orderId) => orderId != 'user:$id')
          .toList();

      String? newActiveId = s.activeUserPresetId;
      if (newActiveId == id) {
        newActiveId = newUserPresets.isNotEmpty
            ? newUserPresets.first.id
            : null;
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

  void updateMapStyleMode(MapStyleMode mode) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => s.copyWith(mapStyleMode: mode),
    );
  }

  void cyclePreset({required bool brighter}) {
    // Unify all monitors to the master ('all') preset order and active preset.
    final currentMap = state.value ?? {'all': SettingsState()};
    final master = currentMap['all'] ?? SettingsState();

    final cycleOrder = master.presetOrder
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
              return master.userPresets.firstWhere((p) => p.id == userId);
            } catch (_) {
              return null;
            }
          }
        })
        .where((item) => item != null)
        .toList();

    if (cycleOrder.isEmpty) return;

    int currentIndex = -1;
    if (master.activeUserPresetId != null) {
      currentIndex = cycleOrder.indexWhere(
        (p) => p is UserPreset && p.id == master.activeUserPresetId,
      );
    } else {
      currentIndex = cycleOrder.indexOf(master.activePreset);
    }

    dynamic next;
    if (currentIndex == -1) {
      next = cycleOrder.first;
    } else {
      int newIndex;
      if (brighter) {
        newIndex = (currentIndex + 1) % cycleOrder.length;
      } else {
        newIndex = (currentIndex - 1 + cycleOrder.length) % cycleOrder.length;
      }
      next = cycleOrder[newIndex];
    }

    // Apply the newly cycled preset & isAutoBrightnessEnabled: true to ALL monitors
    final allMonitorKeys = currentMap.keys.toSet();
    _updateSettings(allMonitorKeys, (s) {
      if (next is PresetType) {
        return s.copyWith(
          activePreset: next,
          clearActiveUserPresetId: true,
          isAutoBrightnessEnabled: true,
          presetOrder: master.presetOrder,
          userPresets: master.userPresets,
        );
      } else if (next is UserPreset) {
        return s.copyWith(
          activeUserPresetId: next.id,
          isAutoBrightnessEnabled: true,
          presetOrder: master.presetOrder,
          userPresets: master.userPresets,
        );
      }
      return s.copyWith(isAutoBrightnessEnabled: true);
    });
  }

  void adjustManualBrightness(double delta) {
    if (!delta.isFinite) return;
    var startingBrightness = ref.read(manualBrightnessProvider);
    final isSoftwareDimmingEnabled = _getSettings(
      'all',
    ).isSoftwareDimmingEnabled;
    final selection = ref.read(selectedMonitorsProvider);
    final monitors = ref.read(monitorListProvider).value ?? [];
    if (_getSettings(
      selection.isEmpty ? 'all' : selection.first,
    ).isAutoBrightnessEnabled) {
      final selected = monitors
          .where(
            (m) =>
                selection.contains('all') || selection.contains(m.deviceName),
          )
          .toList();
      final monitor =
          selected.firstWhereOrNull((m) => m.isPrimary) ?? selected.firstOrNull;
      final applied = monitor == null
          ? null
          : ref
                    .read(brightnessServiceProvider)
                    .getCurrentHardwareBrightness(monitor.deviceName) ??
                monitor.realBrightness;
      // Applied values include monitor offsets; manual state stores the base.
      startingBrightness = applied == null
          ? ref
                    .read(sharedPreferencesProvider)
                    ?.getDouble('last_known_brightness') ??
                startingBrightness
          : applied -
                (_brightnessOffsets(state.value ?? {})[monitor!.deviceName] ??
                    0.0);
    }
    final isOverlayOnly = MonitorInfo.isSelectionOverlayOnly(
      selection,
      monitors,
    );
    final effectiveMin = MonitorInfo.effectiveMinBrightness(
      isOverlayOnly: isOverlayOnly,
      isSoftwareDimmingEnabled: isSoftwareDimmingEnabled,
    );
    final newVal = (startingBrightness + delta).clamp(effectiveMin, 100.0);
    ref.read(manualBrightnessProvider.notifier).update(newVal);
    ref.read(activeProcessServiceProvider.notifier).suppressActiveApp();
    updateAutoBrightness(false);

    // Save to prefs as well (matches setManualBrightness in CurrentBrightnessNotifier)
    ref
        .read(sharedPreferencesProvider)
        ?.setDouble('last_known_brightness', newVal);
  }

  void updateBrightnessStep(bool isUp, double value) {
    _updateSettings(
      ref.read(selectedMonitorsProvider),
      (s) => isUp
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

final webhookServiceProvider =
    NotifierProvider<WebhookService, WebhookServiceState>(WebhookService.new);

class CurrentBrightnessNotifier extends Notifier<double> {
  static const _lastBrightnessKey = 'last_known_brightness';

  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final selection = ref.watch(selectedMonitorsProvider);
    final target = ref.watch(
      brightnessTargetProvider(selection.firstOrNull ?? 'all'),
    );
    if (target == null) return prefs?.getDouble(_lastBrightnessKey) ?? 100;
    if (!target.isManual && target.source != BrightnessSource.game) {
      _saveBrightness(target.value);
    }
    return target.value;
  }

  void _saveBrightness(double value) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setDouble(_lastBrightnessKey, value);
  }

  void setManualBrightness(double value, {String? monitorId}) {
    if (!value.isFinite) return;
    final settingsMap = ref.read(settingsProvider).value ?? {};
    final isSoftwareDimmingEnabled =
        settingsMap['all']?.isSoftwareDimmingEnabled ?? true;

    final monitors = ref.read(monitorListProvider).value ?? [];
    final selection = monitorId != null
        ? {monitorId}
        : ref.read(selectedMonitorsProvider);

    final bool isOverlayOnly = MonitorInfo.isSelectionOverlayOnly(
      selection,
      monitors,
    );
    final effectiveMin = MonitorInfo.effectiveMinBrightness(
      isOverlayOnly: isOverlayOnly,
      isSoftwareDimmingEnabled: isSoftwareDimmingEnabled,
    );

    double baseValue = value;
    if (selection.length == 1 && !selection.contains('all')) {
      final id = selection.first;
      final offsets = ref.read(brightnessOffsetsProvider);
      final offset = offsets[id] ?? 0.0;
      baseValue = (value - offset).clamp(effectiveMin, 100.0);
    } else {
      baseValue = value.clamp(effectiveMin, 100.0);
    }

    ref
        .read(manualBrightnessProvider.notifier)
        .update(baseValue, selection: selection);
    _saveBrightness(baseValue);
    ref.read(activeProcessServiceProvider.notifier).suppressActiveApp();
    ref
        .read(settingsProvider.notifier)
        .updateAutoBrightness(false, monitorId: monitorId);
    state = baseValue;

    ref.read(manualBrightnessApplierProvider)(
      selection: selection,
      targetValue: baseValue,
    );
  }

  void syncManualBrightnessFromMonitor(String monitorId) {
    final settingsMap = ref.read(settingsProvider).value;
    final monitor = ref
        .read(monitorListProvider)
        .value
        ?.firstWhereOrNull(
          (monitor) =>
              monitor.deviceName == monitorId || monitor.id == monitorId,
        );
    if (settingsMap == null || monitor?.realBrightness == null) return;
    final global = settingsMap['all'] ?? SettingsState();
    final settings = settingsMap[monitor!.deviceName] ?? global;
    if (settings.isAutoBrightnessEnabled ||
        (ref.read(gamingModeProvider) && settings.isGameModeEnabled) ||
        _hasBrightnessOverride(
          resolveActiveAppRule(
            settings,
            global,
            ref.read(activeProcessServiceProvider),
          ),
          settings,
        ) ||
        ref
            .read(brightnessServiceProvider)
            .isTransitioning(monitor.deviceName)) {
      return;
    }
    final offset = _brightnessOffsets(settingsMap)[monitor.deviceName] ?? 0.0;
    final minimum = MonitorInfo.effectiveMinBrightness(
      isOverlayOnly: !monitor.isDdcSupported,
      isSoftwareDimmingEnabled: global.isSoftwareDimmingEnabled,
    );
    ref
        .read(manualBrightnessProvider.notifier)
        .update(
          (monitor.realBrightness!.toDouble() - offset).clamp(minimum, 100.0),
          selection: {monitor.deviceName},
        );
  }
}

final currentBrightnessProvider =
    NotifierProvider<CurrentBrightnessNotifier, double>(
      CurrentBrightnessNotifier.new,
    );

/// The dashboard's actual value and explanation must identify the same display.
final brightnessDisplayMonitorProvider = Provider<MonitorInfo?>((ref) {
  final selection = ref.watch(selectedMonitorsProvider);
  final monitors = ref.watch(monitorListProvider).value ?? [];
  final selected = monitors
      .where(
        (m) =>
            selection.contains('all') ||
            selection.contains(m.deviceName) ||
            selection.contains(m.id),
      )
      .toList();
  return selected.firstWhereOrNull((m) => m.isPrimary) ?? selected.firstOrNull;
});

final brightnessOffsetsProvider = Provider<Map<String, double>>((ref) {
  final settingsAsync = ref.watch(settingsProvider);
  return settingsAsync.maybeWhen(data: _brightnessOffsets, orElse: () => {});
});

Map<String, double> _brightnessOffsets(Map<String, SettingsState> settingsMap) {
  if (!(settingsMap['all']?.isMultiMonitorOffsetEnabled ?? false)) return {};
  return {
    for (final entry in settingsMap.entries)
      if (entry.key != 'all') entry.key: entry.value.brightnessOffset,
  };
}

typedef ManualBrightnessApplier =
    void Function({Set<String>? selection, double? targetValue});

final manualBrightnessApplierProvider = Provider<ManualBrightnessApplier>((
  ref,
) {
  return ({Set<String>? selection, double? targetValue}) {
    _applyManualBrightness(ref, selection: selection, targetValue: targetValue);
  };
});

AppOverrideRule? resolveActiveAppRule(
  SettingsState settings,
  SettingsState? global,
  ActiveProcessState process,
) {
  if (process.suppressedPids.isNotEmpty || process.activeProcess.isEmpty) {
    return null;
  }
  return settings.appOverrides.firstWhereOrNull(
        (rule) => rule.isEnabled && rule.exeName == process.activeProcess,
      ) ??
      global?.appOverrides.firstWhereOrNull(
        (rule) => rule.isEnabled && rule.exeName == process.activeProcess,
      );
}

bool _hasBrightnessOverride(AppOverrideRule? rule, SettingsState settings) {
  if (rule == null) return false;
  if (rule.brightnessMode == AppOverrideMode.fixed) {
    return true;
  }
  if (rule.brightnessMode != AppOverrideMode.curve) return false;
  final id = rule.brightnessCurvePresetId;
  if (id == null) return false;
  return settings.userPresets.any(
        (preset) => preset.id == id && preset.points.isNotEmpty,
      ) ||
      PresetType.values.any(
        (preset) =>
            preset.name == id &&
            (settings.curvesMap[preset]?.isNotEmpty ?? false),
      );
}

void _applyManualBrightness(
  Ref ref, {
  Set<String>? selection,
  double? targetValue,
}) {
  if (!ref.mounted) return;
  final settingsMap = ref.read(settingsProvider).value;
  final monitors = ref.read(monitorListProvider).value ?? [];
  if (settingsMap == null || monitors.isEmpty) return;

  final Set<String> selected = selection ?? ref.read(selectedMonitorsProvider);
  final globalSettings = settingsMap['all'] ?? SettingsState();
  final process = ref.read(activeProcessServiceProvider);
  final isGaming = ref.read(gamingModeProvider);
  final offsets = _brightnessOffsets(settingsMap);
  final service = ref.read(brightnessServiceProvider);
  final hardware = ref.read(monitorServiceProvider);
  final notifier = ref.read(monitorListProvider.notifier);
  final double manual = targetValue ?? ref.read(manualBrightnessProvider);
  final visible = ref.read(appLifecycleProvider) == AppVisibilityState.visible;

  for (final monitor in monitors) {
    if (!selected.contains('all') &&
        !selected.contains(monitor.deviceName) &&
        !selected.contains(monitor.id)) {
      continue;
    }
    final settings = settingsMap[monitor.deviceName] ?? globalSettings;
    if (settings.isAutoBrightnessEnabled ||
        (isGaming && settings.isGameModeEnabled)) {
      continue;
    }
    final appRule = resolveActiveAppRule(settings, globalSettings, process);
    if (_hasBrightnessOverride(appRule, settings)) {
      continue;
    }

    service.applyBrightnessSmoothly(
      selection: monitor.deviceName,
      targetValue: manual,
      monitors: monitors,
      monitorService: hardware,
      offsets: offsets,
      isManual: true,
      isUIVisible: visible,
      isSoftwareDimmingEnabled: globalSettings.isSoftwareDimmingEnabled,
      updateBrightnessCallback: notifier.updateBrightness,
    );
  }
}

// Listener lifetime must not depend on the settings changes it applies.
final manualBrightnessAdjustmentProvider = Provider<void>((ref) {
  ref.listen<String>(connectedMonitorDevicesProvider, (previous, next) {
    final previousDevices = previous?.split(';').toSet() ?? <String>{};
    final added = next
        .split(';')
        .where((id) => id.isNotEmpty && !previousDevices.contains(id))
        .toSet();
    if (added.isNotEmpty) _applyManualBrightness(ref, selection: added);
  });
  ref.listen<AsyncValue<Map<String, SettingsState>>>(settingsProvider, (
    previous,
    next,
  ) {
    final current = next.value;
    if (current == null) return;
    final old = previous?.value;
    final monitors = ref.read(monitorListProvider).value ?? [];
    final affected = <String>{};
    for (final monitor in monitors) {
      final settings = current[monitor.deviceName] ?? current['all'];
      final before = old?[monitor.deviceName] ?? old?['all'];
      if (settings != null &&
          !settings.isAutoBrightnessEnabled &&
          (before == null ||
              before.isAutoBrightnessEnabled ||
              before.isSoftwareDimmingEnabled !=
                  settings.isSoftwareDimmingEnabled ||
              before.brightnessOffset != settings.brightnessOffset ||
              before.isMultiMonitorOffsetEnabled !=
                  settings.isMultiMonitorOffsetEnabled ||
              before.isGameModeEnabled != settings.isGameModeEnabled ||
              !identical(before.appOverrides, settings.appOverrides))) {
        affected.add(monitor.deviceName);
      }
    }
    if (affected.isNotEmpty) _applyManualBrightness(ref, selection: affected);
  });
  ref.listen<bool>(gamingModeProvider, (previous, next) {
    if (previous != true || next) return;
    final settings = ref.read(settingsProvider).value ?? {};
    final monitors = ref.read(monitorListProvider).value ?? [];
    final affected = {
      for (final monitor in monitors)
        if ((settings[monitor.deviceName] ?? settings['all'])
                ?.isGameModeEnabled ??
            false)
          monitor.deviceName,
    };
    if (affected.isNotEmpty) _applyManualBrightness(ref, selection: affected);
  });
  ref.listen<ActiveProcessState>(activeProcessServiceProvider, (
    previous,
    next,
  ) {
    if (previous == null ||
        (previous.activeProcess == next.activeProcess &&
            const SetEquality<int>().equals(
              previous.suppressedPids,
              next.suppressedPids,
            ))) {
      return;
    }
    final settingsMap = ref.read(settingsProvider).value ?? {};
    final monitors = ref.read(monitorListProvider).value ?? [];
    final affected = <String>{};
    for (final monitor in monitors) {
      final global = settingsMap['all'] ?? SettingsState();
      final settings = settingsMap[monitor.deviceName] ?? global;
      final previousRule = resolveActiveAppRule(settings, global, previous);
      if (_hasBrightnessOverride(previousRule, settings)) {
        affected.add(monitor.deviceName);
      }
    }
    if (affected.isNotEmpty) _applyManualBrightness(ref, selection: affected);
  });
  ref.listen<Set<String>>(selectedMonitorsProvider, (previous, next) {
    if (next.contains('all')) _applyManualBrightness(ref, selection: next);
  });
  _applyManualBrightness(ref, selection: {'all'});
});

/// Brightness does not wait for the independent temperature settings to load.
final automaticBrightnessAdjustmentProvider = Provider<void>((ref) {
  ref.watch(manualBrightnessAdjustmentProvider);
  ref.watch(connectedMonitorDevicesProvider);
  final monitors = ref.read(monitorListProvider).value ?? [];
  final offsets = ref.watch(brightnessOffsetsProvider);
  final visibility = ref.watch(appLifecycleProvider);
  final settings = ref.watch(settingsProvider).value;
  if (settings == null) return;
  final service = ref.watch(brightnessServiceProvider);
  final monitorService = ref.watch(monitorServiceProvider);
  final notifier = ref.read(monitorListProvider.notifier);
  for (final monitor in monitors) {
    final target = ref.watch(brightnessTargetProvider(monitor.deviceName));
    if (target == null || target.isManual) continue;
    final config =
        settings[monitor.deviceName] ?? settings['all'] ?? SettingsState();
    service.applyBrightnessSmoothly(
      selection: monitor.deviceName,
      targetValue: target.value,
      monitors: monitors,
      monitorService: monitorService,
      offsets: offsets,
      isUIVisible: visibility == AppVisibilityState.visible,
      isSoftwareDimmingEnabled: config.isSoftwareDimmingEnabled,
      updateBrightnessCallback: notifier.updateBrightness,
    );
  }
});

/// Background provider that manages monitor brightness and temperature adjustments.
/// It listens to solar state and applies brightness updates to hardware.
/// If the app is minimized, it skips UI state updates to save resources.
final circadianAdjustmentProvider = Provider<void>((ref) {
  ref.watch(automaticBrightnessAdjustmentProvider);
  ref.watch(autoBrightnessAdjustmentProvider);
  ref.watch(autoTemperatureAdjustmentProvider);
  ref.watch(connectedMonitorDevicesProvider);
  final monitors = ref.read(monitorListProvider).value ?? [];
  final visible = ref.watch(appLifecycleProvider) == AppVisibilityState.visible;
  final service = ref.watch(temperatureServiceProvider);
  final hardware = ref.watch(monitorServiceProvider);
  final notifier = ref.read(monitorListProvider.notifier);
  void confirmed(String id, int value) {
    if (ref.mounted) notifier.updateTemperature(id, value);
  }

  for (final monitor in monitors) {
    final target = ref.watch(temperatureTargetProvider(monitor.deviceName));
    if (target == null) continue;
    if (target.isDisabled) {
      service.stopTemperatureControlForDevice(monitor.deviceName);
    } else if (target.isManual) {
      service.setTemperatureInstant(
        selection: monitor.deviceName,
        targetValue: target.value.toDouble(),
        monitors: monitors,
        monitorService: hardware,
        updateTemperatureCallback: confirmed,
      );
    } else {
      service.applyTemperatureSmoothly(
        selection: monitor.deviceName,
        targetValue: target.value.toDouble(),
        monitors: monitors,
        monitorService: hardware,
        isUIVisible: visible,
        updateTemperatureCallback: confirmed,
      );
    }
  }
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
  String? customToken,
}) {
  final token = (customToken != null && customToken.isNotEmpty)
      ? customToken
      : Env.mapboxToken;
  const width = 600;
  const height = 600;

  return 'https://api.mapbox.com/styles/v1/$style/static/$lon,$lat,$zoom,0,0/${width}x$height?access_token=$token&logo=false&attribution=false';
}
