import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/models/brightness_target.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/night_group.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/models/temperature_target.dart';
import 'package:solaris/providers/regulation_breakdown_provider.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/active_process_service.dart';
import 'package:solaris/services/gaming_mode_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../helpers/brightness_fixtures.dart';
import '../helpers/wait_until.dart';

class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final Map<String, SettingsState> initial;
  @override
  Future<Map<String, SettingsState>> build() async => initial;
  void replace(String id, SettingsState value) =>
      state = AsyncData({...state.value!, id: value});
}

class _Temperature extends TemperatureSettingsNotifier {
  _Temperature(this.pending, this.initial);
  final bool pending;
  final Map<String, TemperatureState>? initial;
  @override
  Future<Map<String, TemperatureState>> build() => pending
      ? Completer<Map<String, TemperatureState>>().future
      : Future.value(initial ?? {'all': TemperatureState(isEnabled: false)});
}

class _Process extends ActiveProcessService {
  @override
  ActiveProcessState build() =>
      const ActiveProcessState(activeProcess: '', windowTitle: '');
  void activate({bool suppressed = false}) => state = ActiveProcessState(
    activeProcess: 'editor.exe',
    windowTitle: 'Editor',
    suppressedPids: suppressed ? {1} : {},
  );
  void deactivate() =>
      state = const ActiveProcessState(activeProcess: '', windowTitle: '');
}

class _Gaming extends GamingModeService {
  @override
  bool build() => false;
  void activate() => state = true;
  void deactivate() => state = false;
}

class _Weather extends WeatherNotifier {
  @override
  Future<WeatherData?> build() async => null;
}

class _Color extends ColorTemperatureEnabledNotifier {
  _Color(this.enabled);
  final bool enabled;
  @override
  bool build() => enabled;
}

class _Monitor extends MonitorService {
  final physical = {'DISPLAY1': 60, 'DISPLAY2': 60};
  final temperatures = {'DISPLAY1': 6500, 'DISPLAY2': 6500};
  final writes = <({String device, int value})>[];
  final temperatureWrites = <({String device, int value})>[];
  bool rejectWrites = false;
  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async => [
    for (final entry in physical.entries)
      MonitorInfo(
        id: entry.key,
        name: entry.key,
        friendlyName: entry.key,
        deviceName: entry.key,
        deviceIdHash: entry.key,
        isPrimary: entry.key == 'DISPLAY1',
        isDdcSupported: true,
        realBrightness: entry.value,
        realTemperature: temperatures[entry.key],
      ),
  ];
  @override
  Future<bool> setMonitorTemperature(String deviceName, int value) async {
    temperatureWrites.add((device: deviceName, value: value));
    temperatures[deviceName] = value;
    return true;
  }

  @override
  Future<bool> resetMonitorTemperature(String deviceName) async {
    for (final id
        in deviceName == 'all' ? temperatures.keys.toList() : [deviceName]) {
      temperatureWrites.add((device: id, value: 6500));
      temperatures[id] = 6500;
    }
    return true;
  }

  @override
  Future<bool> setBrightness(
    String deviceName,
    int brightness, {
    bool isOverlayOnly = false,
  }) async {
    writes.add((device: deviceName, value: brightness));
    if (rejectWrites) return false;
    physical[deviceName] = brightness;
    return true;
  }
}

SleepRegime _lateWakeRegime() {
  final session = SleepSession(
    id: 'synthetic',
    startTime: DateTime(2026, 10, 15, 4),
    endTime: DateTime(2026, 10, 15, 12),
  );
  return SleepRegime(
    id: 'synthetic',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 31),
    averageBedtimeNormalized: 960,
    averageBedtimeFormatted: '04:00',
    averageWakeTimeNormalized: 1440,
    averageWakeTimeFormatted: '12:00',
    windowStart: '04:00',
    windowEnd: '12:00',
    anomalyDates: const [],
    isCurrent: true,
    dayCount: 15,
    isFloating: false,
    nights: [
      NightGroup(date: DateTime(2026, 10, 15), aggregatedSession: session),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz_data.initializeTimeZones);
  late ProviderContainer container;
  late _Monitor monitor;
  late SharedPreferences prefs;

  SettingsState config({CircadianMode mode = CircadianMode.solarPhases}) =>
      SettingsState(
        isAutoBrightnessEnabled: true,
        isSmartCircadianEnabled: false,
        isWeatherAdjustmentEnabled: false,
        circadianMode: mode,
        activePreset: PresetType.brightest,
        curvesMap: {
          ...PresetConstants.getAllDefaults(),
          PresetType.brightest: const [
            FlSpot(-20, 40),
            FlSpot(30, 24),
            FlSpot(90, 20),
          ],
          PresetType.dim: const [
            FlSpot(-20, 5),
            FlSpot(30, 35),
            FlSpot(90, 55),
          ],
        },
      );

  Future<void> start({
    Map<String, SettingsState>? settings,
    bool solarReady = true,
    bool temperaturePending = false,
    bool colorEnabled = false,
    Map<String, TemperatureState>? temperatureSettings,
    bool apply = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'manual_brightness': 60.0,
      'last_known_brightness': 60.0,
    });
    prefs = await SharedPreferences.getInstance();
    monitor = _Monitor();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          () => _Settings(settings ?? {'all': config()}),
        ),
        temperatureSettingsProvider.overrideWith(
          () => _Temperature(temperaturePending, temperatureSettings),
        ),
        monitorServiceProvider.overrideWithValue(monitor),
        activeProcessServiceProvider.overrideWith(_Process.new),
        gamingModeProvider.overrideWith(_Gaming.new),
        currentWeatherProvider.overrideWith(_Weather.new),
        isColorTemperatureEnabledProvider.overrideWith(
          () => _Color(colorEnabled),
        ),
        effectiveTimezoneProvider.overrideWithValue(
          tz.getLocation('Europe/Kyiv'),
        ),
        effectiveLocationProvider.overrideWithValue(
          AsyncData(
            Position(
              latitude: 50.45,
              longitude: 30.52,
              timestamp: brightnessTestNoon,
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            ),
          ),
        ),
        solarStateStreamProvider.overrideWith(
          (ref) => solarReady
              ? Stream.value(brightnessTestSolar(elevation: 60))
              : const Stream.empty(),
        ),
        minuteTimeProvider.overrideWith(
          (ref) => Stream.value(brightnessTestNoon),
        ),
        sleepRegimesProvider.overrideWithValue([_lateWakeRegime()]),
      ],
    );
    addTearDown(container.dispose);
    container.listen(solarStateStreamProvider, (_, _) {});
    container.listen(minuteTimeProvider, (_, _) {});
    await container.read(settingsProvider.future);
    await container.read(monitorListProvider.future);
    await container.read(currentWeatherProvider.future);
    if (!temperaturePending) {
      await container.read(temperatureSettingsProvider.future);
    }
    if (solarReady) await container.read(solarStateStreamProvider.future);
    await container.read(minuteTimeProvider.future);
    container.listen(currentBrightnessProvider, (_, _) {});
    if (apply) container.listen(circadianAdjustmentProvider, (_, _) {});
    await container.pump();
  }

  void replace(SettingsState value, {String id = 'all'}) =>
      (container.read(settingsProvider.notifier) as _Settings).replace(
        id,
        value,
      );

  Future<void> settles(Map<String, int> expected) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline) &&
        expected.entries.any((e) => monitor.physical[e.key] != e.value)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(monitor.physical, expected);
  }

  test(
    'phases and disabled Smart Circadian agree across explanation, UI and hardware',
    () async {
      await start(apply: true);
      final data = container.read(smartCircadianDataProvider('DISPLAY1'));
      expect(data.baseBrightness, 100);
      expect(data.finalBrightness, 100);
      expect(data.timeOffset, Duration.zero);
      expect(data.timeShiftBrightnessImpact, 0);
      expect(data.elevationShiftBrightnessImpact, 0);
      expect(container.read(currentBrightnessProvider), 100);
      expect(
        container.read(brightnessTargetProvider('DISPLAY1'))!.source,
        BrightnessSource.solarPhases,
      );
      await settles({'DISPLAY1': 100, 'DISPLAY2': 100});
    },
  );

  test(
    'the master toggle neutralizes real sleep adjustments and restores them when enabled',
    () async {
      await start();
      replace(config().copyWith(isSmartCircadianEnabled: true));
      await container.pump();
      final enabled = container.read(smartCircadianDataProvider('all'));
      expect(enabled.timeOffset, isNot(Duration.zero));
      expect(enabled.isTimeShiftActive, isTrue);
      expect(enabled.elevationShiftBrightnessImpact, isNot(0));
      replace(config());
      await container.pump();
      final disabled = container.read(smartCircadianDataProvider('all'));
      expect(disabled.timeOffset, Duration.zero);
      expect(disabled.isTimeShiftActive, isFalse);
      expect(disabled.baseBrightness, 100);
      expect(disabled.finalBrightness, 100);
    },
  );

  test(
    'switching phases to a descending curve changes the actual hardware target',
    () async {
      await start(apply: true);
      await settles({'DISPLAY1': 100, 'DISPLAY2': 100});
      replace(config(mode: CircadianMode.normalizedCurve));
      await container.pump();
      final target = container.read(brightnessTargetProvider('DISPLAY1'))!;
      expect(target.source, BrightnessSource.curve);
      expect(target.value, closeTo(22, 1e-9));
      expect(target.data.baseBrightness, target.value);
      expect(container.read(currentBrightnessProvider), target.value);
      await settles({'DISPLAY1': 22, 'DISPLAY2': 22});
    },
  );

  test(
    'brightness applies while temperature settings are still loading',
    () async {
      await start(temperaturePending: true, apply: true);
      await settles({'DISPLAY1': 100, 'DISPLAY2': 100});
    },
  );

  test(
    'missing solar data has no fabricated explanation or automatic writes',
    () async {
      await start(solarReady: false, apply: true);
      expect(container.read(brightnessTargetProvider('all')), isNull);
      expect(container.read(currentBrightnessProvider), 60);
      expect(monitor.writes, isEmpty);
    },
  );

  test('fixed application overrides work without solar data', () async {
    final settings = config().copyWith(
      appOverrides: const [
        AppOverrideRule(
          exeName: 'editor.exe',
          appDisplayName: 'Editor',
          brightnessMode: AppOverrideMode.fixed,
          fixedBrightness: 72,
        ),
      ],
    );
    await start(settings: {'all': settings}, solarReady: false, apply: true);
    (container.read(activeProcessServiceProvider.notifier) as _Process)
        .activate();
    await container.pump();
    final target = container.read(brightnessTargetProvider('DISPLAY1'))!;
    expect(target.source, BrightnessSource.appFixed);
    expect(target.applicationName, 'Editor');
    expect(target.value, 72);
    await settles({'DISPLAY1': 72, 'DISPLAY2': 72});
  });

  test(
    'different per-monitor application overrides do not reuse the selected monitor target',
    () async {
      SettingsState app(double value) => config().copyWith(
        appOverrides: [
          AppOverrideRule(
            exeName: 'editor.exe',
            appDisplayName: 'Editor',
            brightnessMode: AppOverrideMode.fixed,
            fixedBrightness: value,
          ),
        ],
      );
      await start(
        settings: {'all': config(), 'DISPLAY1': app(68), 'DISPLAY2': app(81)},
        apply: true,
      );
      (container.read(activeProcessServiceProvider.notifier) as _Process)
          .activate();
      await container.pump();
      expect(container.read(brightnessTargetProvider('DISPLAY1'))!.value, 68);
      expect(container.read(brightnessTargetProvider('DISPLAY2'))!.value, 81);
      await settles({'DISPLAY1': 68, 'DISPLAY2': 81});
    },
  );

  test(
    'an application curve uses its own preset and mode above phases and gaming',
    () async {
      final settings = config().copyWith(
        isGameModeEnabled: true,
        gameModeBrightness: 90,
        appOverrides: [
          AppOverrideRule(
            exeName: 'editor.exe',
            appDisplayName: 'Editor',
            brightnessMode: AppOverrideMode.curve,
            brightnessCurvePresetId: PresetType.dim.name,
          ),
        ],
      );
      await start(settings: {'all': settings}, apply: true);
      (container.read(gamingModeProvider.notifier) as _Gaming).activate();
      (container.read(activeProcessServiceProvider.notifier) as _Process)
          .activate();
      await container.pump();
      final target = container.read(brightnessTargetProvider('DISPLAY1'))!;
      expect(target.source, BrightnessSource.appCurve);
      expect(target.systemPreset, PresetType.dim);
      expect(target.value, 45);
      await settles({'DISPLAY1': 45, 'DISPLAY2': 45});
    },
  );

  test(
    'deleted application preset falls back through gaming to normal phases',
    () async {
      final settings = config().copyWith(
        isGameModeEnabled: true,
        gameModeBrightness: 75,
        appOverrides: const [
          AppOverrideRule(
            exeName: 'editor.exe',
            appDisplayName: 'Editor',
            brightnessMode: AppOverrideMode.curve,
            brightnessCurvePresetId: 'deleted',
          ),
        ],
      );
      await start(settings: {'all': settings});
      (container.read(activeProcessServiceProvider.notifier) as _Process)
          .activate();
      expect(
        container.read(brightnessTargetProvider('all'))!.source,
        BrightnessSource.solarPhases,
      );
      (container.read(gamingModeProvider.notifier) as _Gaming).activate();
      expect(
        container.read(brightnessTargetProvider('all'))!.source,
        BrightnessSource.game,
      );
      expect(container.read(currentBrightnessProvider), 75);
    },
  );

  test('suppression bypasses the application override', () async {
    await start(
      settings: {
        'all': config().copyWith(
          appOverrides: const [
            AppOverrideRule(
              exeName: 'editor.exe',
              appDisplayName: 'Editor',
              brightnessMode: AppOverrideMode.fixed,
              fixedBrightness: 72,
            ),
          ],
        ),
      },
    );
    (container.read(activeProcessServiceProvider.notifier) as _Process)
        .activate(suppressed: true);
    expect(
      container.read(brightnessTargetProvider('all'))!.source,
      BrightnessSource.solarPhases,
    );
    expect(container.read(currentBrightnessProvider), 100);
  });

  for (final pending in [false, true]) {
    test(
      'a saved fixed temperature without a value resolves to the displayed default (pending: $pending)',
      () async {
        final rule = AppOverrideRule.fromJson({
          'exeName': 'editor.exe',
          'appDisplayName': 'Editor',
          'brightnessMode': 'fixed',
          'fixedBrightness': 100.0,
          'temperatureMode': 'fixed',
          'fixedTemperature': null,
        });
        await start(
          settings: {
            'all': config().copyWith(
              appOverrides: [rule],
              isWeatherTemperatureAdjustmentEnabled: true,
            ),
          },
          colorEnabled: true,
          solarReady: !pending,
          temperaturePending: pending,
          temperatureSettings: {'all': TemperatureState(isEnabled: true)},
        );
        (container.read(activeProcessServiceProvider.notifier) as _Process)
            .activate();
        await container.pump();
        for (final id in ['all', 'DISPLAY1', 'DISPLAY2']) {
          expect(container.read(brightnessTargetProvider(id))!.value, 100);
          final target = container.read(temperatureTargetProvider(id))!;
          expect(target.source, TemperatureSource.appFixed);
          expect(target.value, 6500);
          expect(target.data.weatherTemperatureImpact, 0);
          expect(target.data.timeShiftTemperatureImpact, 0);
        }
      },
    );
  }

  test(
    'fixed defaults override manual modes and are applied to both monitors',
    () async {
      await start(
        settings: {
          'all': config().copyWith(
            isAutoBrightnessEnabled: false,
            appOverrides: const [
              AppOverrideRule(
                exeName: 'editor.exe',
                appDisplayName: 'Editor',
                brightnessMode: AppOverrideMode.fixed,
                temperatureMode: AppOverrideMode.fixed,
              ),
            ],
          ),
        },
        colorEnabled: true,
        temperatureSettings: {
          'all': TemperatureState(isEnabled: false, manualTemperature: 3500),
        },
        apply: true,
      );
      await waitUntil(
        () => monitor.temperatures.values.every((value) => value == 3500),
      );
      final process =
          container.read(activeProcessServiceProvider.notifier) as _Process;
      process.activate();
      await container.pump();
      await settles({'DISPLAY1': 80, 'DISPLAY2': 80});
      await waitUntil(
        () => monitor.temperatures.values.every((value) => value == 6500),
      );
      expect(
        monitor.temperatureWrites
            .where((write) => write.value == 6500)
            .map((write) => write.device)
            .toSet(),
        {'DISPLAY1', 'DISPLAY2'},
      );
      process.deactivate();
      await container.pump();
      await settles({'DISPLAY1': 60, 'DISPLAY2': 60});
      await waitUntil(
        () => monitor.temperatures.values.every((value) => value == 3500),
      );
    },
  );

  test(
    'monitor offsets apply once and never replace the saved manual base',
    () async {
      final global = config(
        mode: CircadianMode.normalizedCurve,
      ).copyWith(isMultiMonitorOffsetEnabled: true);
      await start(
        settings: {
          'all': global,
          'DISPLAY1': global.copyWith(brightnessOffset: 7),
          'DISPLAY2': global.copyWith(brightnessOffset: -5),
        },
        apply: true,
      );
      await settles({'DISPLAY1': 29, 'DISPLAY2': 17});
      expect(container.read(brightnessTargetProvider('DISPLAY1'))!.value, 22);
      expect(prefs.getDouble('manual_brightness'), 60);
    },
  );

  test('dashboard representative belongs to the current selection', () async {
    await start();
    expect(
      container.read(brightnessDisplayMonitorProvider)!.deviceName,
      'DISPLAY1',
    );
    container.read(selectedMonitorsProvider.notifier).selectOnly('DISPLAY2');
    expect(
      container.read(brightnessDisplayMonitorProvider)!.deviceName,
      'DISPLAY2',
    );
  });

  test(
    'manual mode restores its base after the automatic transition',
    () async {
      await start(apply: true);
      await settles({'DISPLAY1': 100, 'DISPLAY2': 100});
      replace(config().copyWith(isAutoBrightnessEnabled: false));
      await container.pump();
      expect(
        container.read(brightnessTargetProvider('all'))!.source,
        BrightnessSource.manual,
      );
      expect(container.read(currentBrightnessProvider), 60);
      await settles({'DISPLAY1': 60, 'DISPLAY2': 60});
    },
  );

  test(
    'rejected writes preserve the confirmed value while retaining the target',
    () async {
      await start();
      monitor.rejectWrites = true;
      container.listen(automaticBrightnessAdjustmentProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(monitor.writes, isNotEmpty);
      expect(container.read(brightnessTargetProvider('DISPLAY1'))!.value, 100);
      expect(
        container.read(brightnessDisplayMonitorProvider)!.realBrightness,
        60,
      );
      expect(monitor.physical, {'DISPLAY1': 60, 'DISPLAY2': 60});
    },
  );

  test(
    'a new target supersedes an automatic transition already in progress',
    () async {
      await start(
        settings: {'all': config(mode: CircadianMode.normalizedCurve)},
        apply: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      replace(config());
      await container.pump();
      await settles({'DISPLAY1': 100, 'DISPLAY2': 100});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(monitor.physical, {'DISPLAY1': 100, 'DISPLAY2': 100});
      expect(container.read(currentBrightnessProvider), 100);
    },
  );

  test(
    'user preset identity and points are preserved for both normal and application curves',
    () async {
      final user = UserPreset(
        id: 'reading',
        name: 'Reading',
        points: const [FlSpot(-20, 50), FlSpot(90, 50)],
      );
      final settings = config(mode: CircadianMode.normalizedCurve).copyWith(
        userPresets: [user],
        activeUserPresetId: user.id,
        appOverrides: [
          AppOverrideRule(
            exeName: 'editor.exe',
            appDisplayName: 'Editor',
            brightnessMode: AppOverrideMode.curve,
            brightnessCurvePresetId: user.id,
          ),
        ],
      );
      await start(settings: {'all': settings});
      var target = container.read(brightnessTargetProvider('all'))!;
      expect(target.source, BrightnessSource.curve);
      expect(target.value, 50);
      expect(target.userPresetName, 'Reading');
      expect(target.systemPreset, isNull);
      (container.read(activeProcessServiceProvider.notifier) as _Process)
          .activate();
      target = container.read(brightnessTargetProvider('all'))!;
      expect(target.source, BrightnessSource.appCurve);
      expect(target.value, 50);
      expect(target.userPresetName, 'Reading');
      expect(target.systemPreset, isNull);
    },
  );

  test('gaming brightness resolves before solar data is available', () async {
    await start(
      solarReady: false,
      settings: {
        'all': config().copyWith(
          isGameModeEnabled: true,
          gameModeBrightness: 77,
        ),
      },
    );
    (container.read(gamingModeProvider.notifier) as _Gaming).activate();
    expect(
      container.read(brightnessTargetProvider('all'))!.source,
      BrightnessSource.game,
    );
    expect(container.read(currentBrightnessProvider), 77);
  });

  test(
    'gaming brightness preserves the saved fallback while solar is loading',
    () async {
      await start(
        solarReady: false,
        settings: {
          'all': config().copyWith(
            isGameModeEnabled: true,
            gameModeBrightness: 77,
          ),
        },
      );
      final gaming = container.read(gamingModeProvider.notifier) as _Gaming;
      gaming.activate();
      await container.pump();
      expect(container.read(currentBrightnessProvider), 77);
      expect(prefs.getDouble('last_known_brightness'), 60);
      expect(prefs.getDouble('manual_brightness'), 60);
      gaming.deactivate();
      await container.pump();
      expect(container.read(currentBrightnessProvider), 60);
      final restarted = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          brightnessTargetProvider.overrideWith((ref, id) => null),
        ],
      );
      addTearDown(restarted.dispose);
      expect(restarted.read(currentBrightnessProvider), 60);
    },
  );

  test(
    'gaming brightness does not overwrite the last automatic target',
    () async {
      await start(
        settings: {
          'all': config().copyWith(
            isGameModeEnabled: true,
            gameModeBrightness: 77,
          ),
        },
      );
      expect(container.read(currentBrightnessProvider), 100);
      expect(prefs.getDouble('last_known_brightness'), 100);
      final gaming = container.read(gamingModeProvider.notifier) as _Gaming;
      gaming.activate();
      await container.pump();
      expect(container.read(currentBrightnessProvider), 77);
      expect(prefs.getDouble('last_known_brightness'), 100);
      gaming.deactivate();
      await container.pump();
      expect(container.read(currentBrightnessProvider), 100);
    },
  );

  test(
    'temperature explanations also neutralize disabled sleep corrections',
    () async {
      await start();
      await container.read(temperatureSettingsProvider.future);
      final data = container.read(smartCircadianTemperatureDataProvider('all'));
      expect(data.isTimeShiftActive, isFalse);
      expect(data.timeShiftTemperatureImpact, 0);
      expect(data.finalTemperature, 6500);
    },
  );

  for (final appCurve in [false, true]) {
    test(
      'temperature range metadata reaches the ${appCurve ? 'application' : 'automatic'} target',
      () async {
        final settings = config(mode: CircadianMode.normalizedCurve).copyWith(
          appOverrides: appCurve
              ? [
                  AppOverrideRule(
                    exeName: 'editor.exe',
                    appDisplayName: 'Editor',
                    temperatureMode: AppOverrideMode.curve,
                    temperatureCurvePresetId: TemperaturePresetType.custom.name,
                  ),
                ]
              : const [],
        );
        await start(
          settings: {'all': settings},
          colorEnabled: true,
          temperatureSettings: {
            'all': TemperatureState(
              isEnabled: true,
              activePreset: TemperaturePresetType.custom,
              curvesMap: {
                ...PresetConstants.getAllTemperatureDefaults(),
                TemperaturePresetType.custom: const [
                  FlSpot(-20, 850),
                  FlSpot(90, 850),
                ],
              },
            ),
          },
        );
        if (appCurve) {
          (container.read(activeProcessServiceProvider.notifier) as _Process)
              .activate();
        }
        final target = container.read(temperatureTargetProvider('DISPLAY1'))!;
        expect(
          target.source,
          appCurve ? TemperatureSource.appCurve : TemperatureSource.curve,
        );
        expect(target.value, 1000);
        expect(target.data.baseTemperature, 850);
        expect(target.data.temperatureLimitImpact, 150);
        expect(target.data.temperatureRoundingImpact, 0);
        final grouped = container
            .read(regulationBreakdownProvider)
            .temperature
            .single;
        expect(grouped.representative.target!.data, target.data);
      },
    );
  }
  test(
    'equal effective calculations group all displays with link and offsets off',
    () async {
      await start();
      final groups = container.read(regulationBreakdownProvider);
      expect(groups.allSelected, isTrue);
      expect(groups.selectedCount, 2);
      expect(groups.brightness, hasLength(1));
      expect(groups.brightness.single.members, hasLength(2));
    },
  );

  test(
    'sleep coupling only on the second display produces separate brightness checks',
    () async {
      final common = config();
      await start(
        settings: {
          'all': common,
          'DISPLAY1': common,
          'DISPLAY2': common.copyWith(isSmartCircadianEnabled: true),
        },
      );
      final groups = container.read(regulationBreakdownProvider).brightness;
      expect(groups, hasLength(2));
      expect(groups[0].representative.target!.data.isTimeShiftActive, isFalse);
      expect(groups[1].representative.target!.data.isTimeShiftActive, isTrue);
      container.read(selectedMonitorsProvider.notifier).selectOnly('DISPLAY1');
      var selected = container.read(regulationBreakdownProvider);
      expect(selected.allSelected, isFalse);
      expect(
        selected
            .brightness
            .single
            .representative
            .target!
            .data
            .isTimeShiftActive,
        isFalse,
      );
      container.read(selectedMonitorsProvider.notifier).selectOnly('DISPLAY2');
      selected = container.read(regulationBreakdownProvider);
      expect(
        selected
            .brightness
            .single
            .representative
            .target!
            .data
            .isTimeShiftActive,
        isTrue,
      );
    },
  );

  test(
    'equal final targets with different effective control settings are not merged',
    () async {
      final common = config();
      await start(
        settings: {
          'all': common,
          'DISPLAY1': common,
          'DISPLAY2': common.copyWith(isWeatherAdjustmentEnabled: true),
        },
      );
      final groups = container.read(regulationBreakdownProvider).brightness;
      expect(groups, hasLength(2));
      expect(
        groups[0].representative.target!.value,
        groups[1].representative.target!.value,
      );
    },
  );

  test(
    'different temperature corrections do not split an equal brightness calculation',
    () async {
      final common = config().copyWith(isSmartCircadianEnabled: true);
      await start(
        settings: {'all': common},
        colorEnabled: true,
        temperatureSettings: {
          'all': TemperatureState(isEnabled: true),
          'DISPLAY1': TemperatureState(
            isEnabled: true,
            isTimeShiftEnabled: false,
          ),
          'DISPLAY2': TemperatureState(
            isEnabled: true,
            isTimeShiftEnabled: true,
          ),
        },
      );
      final selected = container.read(regulationBreakdownProvider);
      expect(selected.brightness, hasLength(1));
      expect(selected.temperature, hasLength(2));
      expect(
        selected.temperature[0].representative.target!.data.isTimeShiftActive,
        isFalse,
      );
      expect(
        selected.temperature[1].representative.target!.data.isTimeShiftActive,
        isTrue,
      );
    },
  );

  test(
    'per-display temperature rules share the exact target used by hardware',
    () async {
      SettingsState rule(int value) => config().copyWith(
        appOverrides: [
          AppOverrideRule(
            exeName: 'editor.exe',
            appDisplayName: 'Editor',
            temperatureMode: AppOverrideMode.fixed,
            fixedTemperature: value.toDouble(),
          ),
        ],
      );
      await start(
        settings: {
          'all': config(),
          'DISPLAY1': rule(4000),
          'DISPLAY2': rule(5000),
        },
        colorEnabled: true,
        apply: true,
      );
      (container.read(activeProcessServiceProvider.notifier) as _Process)
          .activate();
      await container.pump();
      expect(
        container.read(temperatureTargetProvider('DISPLAY1'))!.source,
        TemperatureSource.appFixed,
      );
      final groups = container.read(regulationBreakdownProvider).temperature;
      expect(groups, hasLength(2));
      expect(groups[0].representative.target!.value, 4000);
      expect(groups[1].representative.target!.value, 5000);
      final until = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(until) &&
          (monitor.temperatures['DISPLAY1'] != 4000 ||
              monitor.temperatures['DISPLAY2'] != 5000)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(monitor.temperatures, {'DISPLAY1': 4000, 'DISPLAY2': 5000});
    },
  );

  test(
    'offsets and mixed automatic/manual control retain separate checks',
    () async {
      final common = config().copyWith(isMultiMonitorOffsetEnabled: true);
      await start(
        settings: {
          'all': common,
          'DISPLAY1': common.copyWith(brightnessOffset: 3),
          'DISPLAY2': common.copyWith(isAutoBrightnessEnabled: false),
        },
      );
      final groups = container.read(regulationBreakdownProvider).brightness;
      expect(groups, hasLength(2));
      expect(groups[0].representative.offset, 3);
      expect(groups[1].representative.target!.isManual, isTrue);
    },
  );

  test(
    'different confirmed progress does not split the same target into flickering groups',
    () async {
      await start();
      container
          .read(monitorListProvider.notifier)
          .updateBrightness('DISPLAY1', 80);
      container
          .read(monitorListProvider.notifier)
          .updateBrightness('DISPLAY2', 70);
      final group = container
          .read(regulationBreakdownProvider)
          .brightness
          .single;
      expect(group.members.map((m) => m.appliedValue), [80, 70]);
      expect(group.members.map((m) => m.target!.value), [100, 100]);
    },
  );

  test(
    'inactive curve presets do not split identical day-phase calculations',
    () async {
      final common = config();
      await start(
        settings: {
          'all': common,
          'DISPLAY1': common,
          'DISPLAY2': common.copyWith(activePreset: PresetType.dim),
        },
      );
      expect(
        container.read(regulationBreakdownProvider).brightness,
        hasLength(1),
      );
    },
  );

  test(
    'turning off a display-specific weather setting reunites equivalent checks',
    () async {
      final common = config();
      await start(
        settings: {
          'all': common,
          'DISPLAY1': common,
          'DISPLAY2': common.copyWith(isWeatherAdjustmentEnabled: true),
        },
      );
      container.listen(regulationBreakdownProvider, (_, _) {});
      expect(
        container.read(regulationBreakdownProvider).brightness,
        hasLength(2),
      );
      replace(common, id: 'DISPLAY2');
      await container.pump();
      expect(
        container.read(regulationBreakdownProvider).brightness.single.members,
        hasLength(2),
      );
    },
  );

  test(
    'the temperature sleep master may be disabled independently on one display',
    () async {
      final common = config().copyWith(isSmartCircadianEnabled: true);
      await start(
        settings: {'all': common},
        colorEnabled: true,
        temperatureSettings: {
          'all': TemperatureState(isEnabled: true),
          'DISPLAY1': TemperatureState(
            isEnabled: true,
            isSmartCircadianEnabled: false,
          ),
          'DISPLAY2': TemperatureState(isEnabled: true),
        },
      );
      final groups = container.read(regulationBreakdownProvider);
      expect(groups.brightness, hasLength(1));
      expect(groups.temperature, hasLength(2));
      expect(
        groups.temperature[0].representative.target!.data.isTimeShiftActive,
        isFalse,
      );
      expect(
        groups.temperature[1].representative.target!.data.isTimeShiftActive,
        isTrue,
      );
    },
  );

  test(
    'temperature application curves retain their own source above global phases',
    () async {
      final common = config().copyWith(
        appOverrides: [
          AppOverrideRule(
            exeName: 'editor.exe',
            appDisplayName: 'Editor',
            temperatureMode: AppOverrideMode.curve,
            temperatureCurvePresetId: TemperaturePresetType.custom.name,
          ),
        ],
      );
      final temp = TemperatureState(
        isEnabled: true,
        curvesMap: {
          ...PresetConstants.getAllTemperatureDefaults(),
          TemperaturePresetType.custom: const [
            FlSpot(-20, 4200),
            FlSpot(90, 4200),
          ],
        },
      );
      await start(
        settings: {'all': common},
        colorEnabled: true,
        temperatureSettings: {'all': temp},
      );
      (container.read(activeProcessServiceProvider.notifier) as _Process)
          .activate();
      final target = container.read(temperatureTargetProvider('DISPLAY1'))!;
      expect(target.source, TemperatureSource.appCurve);
      expect(target.systemPreset, TemperaturePresetType.custom);
      expect(target.value, 4200);
    },
  );

  test(
    'unavailable calculations never form an assumed all-display group',
    () async {
      await start(solarReady: false);
      final selected = container.read(regulationBreakdownProvider);
      expect(selected.brightness, hasLength(2));
      expect(
        selected.brightness.every((g) => g.representative.target == null),
        isTrue,
      );
    },
  );
}
