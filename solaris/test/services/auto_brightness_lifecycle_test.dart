// ignore_for_file: avoid_print
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/temperature_service.dart';
import 'package:timezone/data/latest.dart' as tz;

class AutoReproMonitorService extends MonitorService {
  final List<Map<String, dynamic>> setBrightnessCalls = [];
  final List<Map<String, dynamic>> setTemperatureCalls = [];

  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async {
    return [
      MonitorInfo(
        id: r'\\.\DISPLAY1',
        name: 'Display 1',
        friendlyName: 'Test Monitor 1',
        deviceName: r'\\.\DISPLAY1',
        deviceIdHash: 'hash1',
        isPrimary: true,
        realBrightness: 50,
        realTemperature: 6500,
      ),
    ];
  }

  @override
  Future<bool> setBrightness(
    String deviceName,
    int brightness, {
    bool isOverlayOnly = false,
  }) async {
    setBrightnessCalls.add({
      'device': deviceName,
      'brightness': brightness,
      'isOverlayOnly': isOverlayOnly,
    });
    return true;
  }

  @override
  Future<bool> setMonitorTemperature(String selection, int kelvins) async {
    setTemperatureCalls.add({'selection': selection, 'kelvins': kelvins});
    return true;
  }

  @override
  Future<bool> resetMonitorTemperature(String selection) async {
    setTemperatureCalls.add({
      'selection': selection,
      'kelvins': 6500,
      'reset': true,
    });
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => '.',
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.solaris.monitor/names'),
          (MethodCall methodCall) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          (MethodCall methodCall) async => null,
        );
  });

  test('Auto Brightness & Temperature after minimize-restore cycle', () async {
    final mockMonitorService = AutoReproMonitorService();
    final brightnessService = BrightnessService();
    final tempService = TemperatureService();

    final container = ProviderContainer(
      overrides: [
        monitorServiceProvider.overrideWithValue(mockMonitorService),
        brightnessServiceProvider.overrideWithValue(brightnessService),
        temperatureServiceProvider.overrideWithValue(tempService),
        effectiveLocationProvider.overrideWithValue(
          AsyncData(
            Position(
              latitude: 50.4501,
              longitude: 30.5234,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    // main.dart listening
    container.listen<void>(circadianAdjustmentProvider, (_, _) {});

    await container.read(monitorListProvider.future);
    await container.read(settingsProvider.future);
    await container.read(temperatureSettingsProvider.future);

    // Wait for initial auto-brightness cycle
    await Future<void>.delayed(const Duration(milliseconds: 600));
    print('Initial brightness calls: ${mockMonitorService.setBrightnessCalls}');

    // 1. User changes brightness and temperature manually
    print('--- USER SETS MANUAL BRIGHTNESS (32%) & TEMPERATURE (4000K) ---');
    container.read(autoBrightnessAdjustmentProvider.notifier).setEnabled(false);
    container
        .read(currentBrightnessProvider.notifier)
        .setManualBrightness(32.0);
    container
        .read(currentTemperatureProvider.notifier)
        .setManualTemperature(4000);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    print('Calls after manual 32%: ${mockMonitorService.setBrightnessCalls}');
    print(
      'Temp calls after manual 4000K: ${mockMonitorService.setTemperatureCalls}',
    );

    // 2. User minimizes app
    print('--- MINIMIZING APP ---');
    container.read(appLifecycleProvider.notifier).setMinimized();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // 3. User restores app
    print('--- RESTORING APP ---');
    container.read(appLifecycleProvider.notifier).setVisible();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // 4. User enables Auto Brightness
    print('--- USER ENABLES AUTO BRIGHTNESS ---');
    mockMonitorService.setBrightnessCalls.clear();
    container.read(autoBrightnessAdjustmentProvider.notifier).setEnabled(true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    print(
      'Calls after enabling auto-brightness: ${mockMonitorService.setBrightnessCalls}',
    );

    expect(
      mockMonitorService.setBrightnessCalls.isNotEmpty,
      isTrue,
      reason: 'Auto-brightness MUST apply to hardware when enabled!',
    );

    // 5. User enables Auto Temperature
    print('--- USER ENABLES AUTO TEMPERATURE ---');
    mockMonitorService.setTemperatureCalls.clear();
    container.read(autoTemperatureAdjustmentProvider.notifier).toggle();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    print(
      'Calls after enabling auto-temperature: ${mockMonitorService.setTemperatureCalls}',
    );

    expect(
      mockMonitorService.setTemperatureCalls.isNotEmpty,
      isTrue,
      reason: 'Auto-temperature MUST apply to hardware when enabled!',
    );
  });
}
