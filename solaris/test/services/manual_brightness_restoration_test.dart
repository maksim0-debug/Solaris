import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solaris/models/current_day_phase.dart';
import 'package:solaris/models/app_override_rule.dart';
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/models/solar_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/active_process_service.dart';
import 'package:solaris/services/gaming_mode_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:solaris/services/weather_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../helpers/wait_until.dart';

class _MemoryStorage implements StorageService {
  final values = <String, String>{};

  @override
  Future<String?> load(String filename) async => values[filename];

  @override
  Future<void> save(String filename, String content) async {
    values[filename] = content;
  }

  @override
  Future<void> clear(String filename) async => values.remove(filename);
}

class _Settings extends SettingsNotifier {
  final List<AppOverrideRule> rules;
  final double automaticBrightness;
  _Settings({this.rules = const [], this.automaticBrightness = 99});
  @override
  Future<Map<String, SettingsState>> build() async => {
    'all': SettingsState(
      isAutoBrightnessEnabled: false,
      isSmartCircadianEnabled: false,
      isWeatherAdjustmentEnabled: false,
      appOverrides: rules,
      phasesConfig: SolarPhasesConfig(
        night: PhaseTarget(brightness: automaticBrightness, temperature: 6500),
        sunrise: PhaseTarget(
          brightness: automaticBrightness,
          temperature: 6500,
        ),
        day: PhaseTarget(brightness: automaticBrightness, temperature: 6500),
        sunset: PhaseTarget(brightness: automaticBrightness, temperature: 6500),
      ),
    ),
  };
}

class _Process extends ActiveProcessService {
  @override
  ActiveProcessState build() =>
      const ActiveProcessState(activeProcess: '', windowTitle: '');
}

class _Gaming extends GamingModeService {
  @override
  bool build() => false;
}

class _Weather extends WeatherNotifier {
  @override
  Future<WeatherData?> build() async => null;
}

class _Color extends ColorTemperatureEnabledNotifier {
  @override
  bool build() => false;
}

class _Monitor extends MonitorService {
  final physical = <String, int>{'DISPLAY1': 99, 'DISPLAY2': 99};
  final writes = <({String device, int value, bool overlay})>[];

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
        realBrightness: entry.value,
        isDdcSupported: entry.key == 'DISPLAY1',
      ),
  ];

  @override
  Future<bool> setBrightness(
    String deviceName,
    int brightness, {
    bool isOverlayOnly = false,
  }) async {
    writes.add((device: deviceName, value: brightness, overlay: isOverlayOnly));
    physical[deviceName] = brightness;
    return true;
  }
}

class _PendingTemperature extends TemperatureSettingsNotifier {
  @override
  Future<Map<String, TemperatureState>> build() =>
      Completer<Map<String, TemperatureState>>().future;
}

SolarState _solar() {
  final date = DateTime(2026, 10, 13);
  DateTime hour(int value) => date.add(Duration(hours: value));
  return SolarState(
    phases: SolarPhaseModel(
      sunrise: hour(7),
      sunset: hour(18),
      goldenHourMorning: hour(7),
      goldenHourMorningEnd: hour(8),
      goldenHourEvening: hour(17),
      goldenHourEveningEnd: hour(18),
      civilTwilightBegin: hour(6),
      nextDayCivilTwilightBegin: (hour(6)).add(const Duration(days: 1)),
      civilTwilightEnd: hour(19),
      astronomicalDawn: hour(5),
      civilDusk: hour(19),
      solarNoon: hour(12),
      astronomicalDusk: hour(20),
    ),
    currentPhase: CurrentDayPhase.zenith,
    timeUntilNextEvent: const Duration(hours: 2),
    nextEventType: SolarEventType.goldenHourEvening,
    sunElevation: 60,
    sunAzimuth: 180,
    sunZenith: 30,
    sunProgress: 0.5,
    uvIndex: 0,
    spectralIntensity: 0,
    azimuthTrend: '',
    elevationTrend: '',
    zenithTrend: '',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Monitor monitor;
  late SharedPreferences prefs;

  Future<void> start({
    bool solarReady = true,
    bool temperatureReady = true,
    List<AppOverrideRule> rules = const [],
    double automaticBrightness = 99,
  }) async {
    tzdata.initializeTimeZones();
    SharedPreferences.setMockInitialValues({
      'manual_brightness': 76.0,
      'last_known_brightness': 99.0,
      'auto_brightness_enabled': false,
    });
    prefs = await SharedPreferences.getInstance();
    monitor = _Monitor();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        storageServiceProvider.overrideWithValue(_MemoryStorage()),
        settingsProvider.overrideWith(
          () =>
              _Settings(rules: rules, automaticBrightness: automaticBrightness),
        ),
        monitorServiceProvider.overrideWithValue(monitor),
        activeProcessServiceProvider.overrideWith(_Process.new),
        gamingModeProvider.overrideWith(_Gaming.new),
        currentWeatherProvider.overrideWith(_Weather.new),
        isColorTemperatureEnabledProvider.overrideWith(_Color.new),
        if (!temperatureReady)
          temperatureSettingsProvider.overrideWith(_PendingTemperature.new),
        effectiveTimezoneProvider.overrideWithValue(
          tz.getLocation('Europe/Kyiv'),
        ),
        solarStateStreamProvider.overrideWith(
          (ref) => solarReady ? Stream.value(_solar()) : const Stream.empty(),
        ),
        smartCircadianAdjustmentsProvider.overrideWith(
          (ref, id) => const SmartCircadianData.neutral(),
        ),
        smartCircadianTemperatureDataProvider.overrideWith(
          (ref, id) => const SmartCircadianData.neutral(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen<void>(circadianAdjustmentProvider, (_, _) {});
    container.listen<double>(currentBrightnessProvider, (_, _) {});
    await container.read(settingsProvider.future);
    await container.read(monitorListProvider.future);
    if (temperatureReady) {
      await container.read(temperatureSettingsProvider.future);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  Future<void> startAutomaticHotkeyScenario() async {
    await start(automaticBrightness: 100);
    container.read(autoBrightnessAdjustmentProvider.notifier).setEnabled(true);
    await waitUntil(
      () => monitor.physical.values.every((value) => value == 100),
      reason:
          'Automatic brightness must settle before the manual hotkey scenario',
    );
    expect(monitor.physical.values, everyElement(100));
    container.read(manualBrightnessProvider.notifier).update(20);
    expect(prefs.getDouble('manual_brightness'), 20);
  }

  for (final delta in [-20.0, 20.0]) {
    test(
      'hotkey $delta starts from automatic 100, not saved manual 20',
      () async {
        await startAutomaticHotkeyScenario();
        final expected = (100 + delta).clamp(0, 100).toDouble();
        container.read(settingsProvider.notifier).adjustManualBrightness(delta);
        expect(container.read(autoBrightnessAdjustmentProvider), false);
        expect(prefs.getDouble('manual_brightness'), expected);
        await Future<void>.delayed(const Duration(milliseconds: 450));
        expect(monitor.physical.values, everyElement(expected.toInt()));
      },
    );
  }

  test(
    'rapid hotkeys accumulate the new manual target before hardware settles',
    () async {
      await startAutomaticHotkeyScenario();
      final settings = container.read(settingsProvider.notifier);
      settings.adjustManualBrightness(-20);
      settings.adjustManualBrightness(-20);
      expect(prefs.getDouble('manual_brightness'), 60);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      expect(monitor.physical.values, everyElement(60));
    },
  );

  test(
    'hotkey uses confirmed progress rather than the automatic target',
    () async {
      await startAutomaticHotkeyScenario();
      container
          .read(brightnessServiceProvider)
          .syncHardwareBrightness('DISPLAY1', 60);
      monitor.physical['DISPLAY1'] = 60;
      container.read(settingsProvider.notifier).adjustManualBrightness(-20);
      expect(prefs.getDouble('manual_brightness'), 40);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      expect(monitor.physical.values, everyElement(40));
    },
  );

  test(
    'automatic hotkey subtracts offsets once using the primary monitor',
    () async {
      await startAutomaticHotkeyScenario();
      final settings = container.read(settingsProvider.notifier);
      settings.updateMultiMonitorOffsetEnabled(true);
      settings.updateMonitorOffset('DISPLAY1', 10);
      settings.updateMonitorOffset('DISPLAY2', -20);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      settings.adjustManualBrightness(-20);
      expect(prefs.getDouble('manual_brightness'), 70);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      expect(monitor.physical, {'DISPLAY1': 80, 'DISPLAY2': 50});
    },
  );

  test(
    'selected overlay hotkey clamps at zero without changing another monitor',
    () async {
      await startAutomaticHotkeyScenario();
      container.read(selectedMonitorsProvider.notifier).selectOnly('DISPLAY2');
      container.read(settingsProvider.notifier).adjustManualBrightness(-200);
      expect(prefs.getDouble('manual_brightness'), 0);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(monitor.physical, {'DISPLAY1': 100, 'DISPLAY2': 0});
    },
  );

  for (final visibility in AppVisibilityState.values) {
    test('76 -> auto 99 -> manual 76 while $visibility', () async {
      await start();
      container.read(appLifecycleProvider.notifier).state = visibility;
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(monitor.physical.values, everyElement(99));
      expect(prefs.getDouble('manual_brightness'), 76);
      monitor.writes.clear();

      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(false);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(container.read(currentBrightnessProvider), 76);
      expect(monitor.physical.values, everyElement(76));
      expect(monitor.writes.where((c) => c.value == 76), hasLength(2));
      expect(prefs.getDouble('manual_brightness'), 76);
    });
  }

  test('cold startup restores manual brightness without solar data', () async {
    await start(solarReady: false);
    expect(container.read(currentBrightnessProvider), 76);
    expect(monitor.physical.values, everyElement(76));
    expect(monitor.writes.where((c) => c.value == 76), hasLength(2));
  });

  test(
    'restore repairs physical drift without changing the manual value',
    () async {
      await start();
      container.read(appLifecycleProvider.notifier).setMinimized();
      monitor.physical.updateAll((_, _) => 99);
      monitor.writes.clear();
      container.read(appLifecycleProvider.notifier).setVisible();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(monitor.physical.values, everyElement(76));
      expect(prefs.getDouble('manual_brightness'), 76);
    },
  );

  test(
    'direct settings mode changes restore only the selected monitor',
    () async {
      await start();
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      container.read(selectedMonitorsProvider.notifier).selectOnly('DISPLAY2');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      monitor.writes.clear();
      container.read(settingsProvider.notifier).updateAutoBrightness(false);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(monitor.physical, {'DISPLAY1': 99, 'DISPLAY2': 76});
      expect(monitor.writes.map((c) => c.device), everyElement('DISPLAY2'));
      expect(monitor.writes.last.overlay, isTrue);
    },
  );

  test(
    'a slider update near the automatic value does not first restore an older manual value',
    () async {
      await start();
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      monitor.writes.clear();
      container
          .read(currentBrightnessProvider.notifier)
          .setManualBrightness(98);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(monitor.physical.values, everyElement(98));
      expect(monitor.writes.map((c) => c.value), everyElement(98));
      expect(prefs.getDouble('manual_brightness'), 98);
    },
  );

  test(
    'explicit monitorId does not change the selected manual monitor',
    () async {
      await start();
      container.read(selectedMonitorsProvider.notifier).selectOnly('DISPLAY2');
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      container.read(selectedMonitorsProvider.notifier).selectOnly('DISPLAY1');
      monitor.writes.clear();
      container
          .read(currentBrightnessProvider.notifier)
          .setManualBrightness(50, monitorId: 'DISPLAY2');
      await waitUntil(
        () =>
            monitor.physical['DISPLAY2'] == 50 &&
            !container
                .read(brightnessServiceProvider)
                .isTransitioning('DISPLAY2'),
        reason:
            'The explicitly targeted transition must finish before checking monitor isolation',
      );
      expect(monitor.physical, {'DISPLAY1': 76, 'DISPLAY2': 50});
      expect(monitor.writes.map((c) => c.device), everyElement('DISPLAY2'));
      expect(
        container
            .read(settingsProvider)
            .value!['DISPLAY2']!
            .isAutoBrightnessEnabled,
        isFalse,
      );
    },
  );

  test(
    'a deleted application curve falls back to manual restoration',
    () async {
      await start(
        solarReady: false,
        rules: [
          const AppOverrideRule(
            exeName: 'editor.exe',
            appDisplayName: 'Editor',
            brightnessMode: AppOverrideMode.curve,
            brightnessCurvePresetId: 'deleted-preset',
          ),
        ],
      );
      container
          .read(activeProcessServiceProvider.notifier)
          .state = const ActiveProcessState(
        activeProcess: 'editor.exe',
        windowTitle: '',
      );
      monitor.physical.updateAll((_, _) => 99);
      for (final id in monitor.physical.keys) {
        container
            .read(brightnessServiceProvider)
            .syncHardwareBrightness(id, 99);
      }
      container.read(settingsProvider.notifier).updateAutoBrightness(false);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(monitor.physical.values, everyElement(76));
    },
  );

  test('reasserting manual mode retries a known hardware mismatch', () async {
    await start();
    monitor.physical.updateAll((_, _) => 99);
    for (final id in monitor.physical.keys) {
      container.read(brightnessServiceProvider).syncHardwareBrightness(id, 99);
    }
    container.read(autoBrightnessAdjustmentProvider.notifier).setEnabled(false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(monitor.physical.values, everyElement(76));
  });

  test(
    'selecting a settled manual monitor preserves its existing level without rewriting hardware',
    () async {
      await start();
      container.read(selectedMonitorsProvider.notifier).selectOnly('DISPLAY2');
      container
          .read(currentBrightnessProvider.notifier)
          .setManualBrightness(50);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      container.read(selectedMonitorsProvider.notifier).selectOnly('DISPLAY1');
      monitor.writes.clear();
      container
          .read(currentBrightnessProvider.notifier)
          .syncManualBrightnessFromMonitor('DISPLAY1');
      await Future<void>.delayed(Duration.zero);
      expect(prefs.getDouble('manual_brightness'), 76);
      expect(monitor.physical, {'DISPLAY1': 76, 'DISPLAY2': 50});
      expect(monitor.writes, isEmpty);
    },
  );

  test(
    'selection never saves an automatic value or an intermediate manual transition',
    () async {
      await start();
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      container
          .read(currentBrightnessProvider.notifier)
          .syncManualBrightnessFromMonitor('DISPLAY1');
      expect(prefs.getDouble('manual_brightness'), 76);
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(false);
      container
          .read(currentBrightnessProvider.notifier)
          .syncManualBrightnessFromMonitor('DISPLAY1');
      expect(prefs.getDouble('manual_brightness'), 76);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(monitor.physical.values, everyElement(76));
    },
  );

  test('manual startup does not wait for temperature settings', () async {
    await start(solarReady: false, temperatureReady: false);
    expect(monitor.physical.values, everyElement(76));
  });

  test(
    'same logical value is restored after hardware drift and a mode change',
    () async {
      await start();
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      container.read(manualBrightnessProvider.notifier).update(99);
      monitor.physical.updateAll((_, _) => 90);
      for (final id in monitor.physical.keys) {
        container
            .read(brightnessServiceProvider)
            .syncHardwareBrightness(id, 90);
      }
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(false);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(monitor.physical.values, everyElement(99));
    },
  );

  test(
    'manual slider changes remain isolated from unselected manual monitors',
    () async {
      await start();
      container.read(selectedMonitorsProvider.notifier).selectOnly('DISPLAY2');
      monitor.writes.clear();
      container
          .read(currentBrightnessProvider.notifier)
          .setManualBrightness(50);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(monitor.physical, {'DISPLAY1': 76, 'DISPLAY2': 50});
      expect(monitor.writes.map((c) => c.device), everyElement('DISPLAY2'));
      container
          .read(activeProcessServiceProvider.notifier)
          .state = const ActiveProcessState(
        activeProcess: 'editor.exe',
        windowTitle: 'Document',
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(monitor.physical['DISPLAY1'], 76);
    },
  );

  test(
    'offsets are applied once and automatic values do not replace manual base',
    () async {
      await start();
      final settings = container.read(settingsProvider.notifier);
      settings.updateMultiMonitorOffsetEnabled(true);
      settings.updateMonitorOffset('DISPLAY1', 10);
      settings.updateMonitorOffset('DISPLAY2', -20);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(monitor.physical, {'DISPLAY1': 86, 'DISPLAY2': 56});
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(monitor.physical, {'DISPLAY1': 100, 'DISPLAY2': 79});
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(false);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(monitor.physical, {'DISPLAY1': 86, 'DISPLAY2': 56});
      expect(prefs.getDouble('manual_brightness'), 76);
    },
  );

  test(
    'game mode retains priority and restores manual brightness on exit',
    () async {
      await start();
      container.read(gamingModeProvider.notifier).setGamingState(true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(monitor.physical.values, everyElement(80));
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(true);
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(false);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(monitor.physical.values, everyElement(80));
      container.read(gamingModeProvider.notifier).setGamingState(false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(monitor.physical.values, everyElement(76));
      expect(prefs.getDouble('manual_brightness'), 76);
    },
  );

  test(
    'application override retains priority and restores manual value on exit',
    () async {
      await start(
        rules: [
          const AppOverrideRule(
            exeName: 'editor.exe',
            appDisplayName: 'Editor',
            brightnessMode: AppOverrideMode.fixed,
            fixedBrightness: 90,
          ),
        ],
      );
      container
          .read(activeProcessServiceProvider.notifier)
          .state = const ActiveProcessState(
        activeProcess: 'editor.exe',
        windowTitle: '',
      );
      await Future<void>.delayed(const Duration(milliseconds: 750));
      expect(monitor.physical.values, everyElement(90));
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(true);
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(false);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(monitor.physical.values, everyElement(90));
      container.read(activeProcessServiceProvider.notifier).state =
          const ActiveProcessState(activeProcess: '', windowTitle: '');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(monitor.physical.values, everyElement(76));
      expect(prefs.getDouble('manual_brightness'), 76);
    },
  );
}
