import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:timezone/data/latest.dart' as tz;

class MockMonitorServiceForLifecycle extends MonitorService {
  final List<Map<String, dynamic>> setBrightnessCalls = [];

  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async {
    return [
      MonitorInfo(
        id: r'\\.\DISPLAY1',
        name: 'Display 1',
        friendlyName: 'Test Monitor',
        deviceName: r'\\.\DISPLAY1',
        deviceIdHash: 'hash1',
        isPrimary: true,
        realBrightness: 50,
      ),
    ];
  }

  @override
  Future<bool> setBrightness(String deviceName, int brightness) async {
    setBrightnessCalls.add({'device': deviceName, 'brightness': brightness});
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

  group('Brightness Lifecycle Resilience & Direct Execution Tests', () {
    test(
      'circadianAdjustmentProvider with container.listen stays alive across minimize and restore',
      () async {
        final mockMonitorService = MockMonitorServiceForLifecycle();
        final brightnessService = BrightnessService();

        final container = ProviderContainer(
          overrides: [
            monitorServiceProvider.overrideWithValue(mockMonitorService),
            brightnessServiceProvider.overrideWithValue(brightnessService),
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

        // Simulating lib/main.dart with container.listen
        container.listen<void>(circadianAdjustmentProvider, (_, _) {});

        await container.read(monitorListProvider.future);
        await container.read(settingsProvider.future);

        // Step 1: Initial manual change while visible
        container
            .read(currentBrightnessProvider.notifier)
            .setManualBrightness(70.0);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        expect(
          mockMonitorService.setBrightnessCalls.any(
            (c) => c['brightness'] == 70,
          ),
          isTrue,
          reason: 'Brightness 70% must be sent while visible',
        );

        // Step 2: Minimize app
        container.read(appLifecycleProvider.notifier).setMinimized();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Step 3: Change brightness via manualBrightnessProvider while minimized (e.g. from background API)
        mockMonitorService.setBrightnessCalls.clear();
        container.read(manualBrightnessProvider.notifier).update(35.0);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(
          mockMonitorService.setBrightnessCalls.any(
            (c) => c['brightness'] == 35,
          ),
          isTrue,
          reason:
              'Brightness 35% must be applied even when minimized due to active container.listen',
        );

        // Step 4: Restore app
        container.read(appLifecycleProvider.notifier).setVisible();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Step 5: Change brightness after restore
        mockMonitorService.setBrightnessCalls.clear();
        container
            .read(currentBrightnessProvider.notifier)
            .setManualBrightness(15.0);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(
          mockMonitorService.setBrightnessCalls.any(
            (c) => c['brightness'] == 15,
          ),
          isTrue,
          reason: 'Brightness 15% must be applied cleanly after restore',
        );
      },
    );

    test(
      'CurrentBrightnessNotifier.setManualBrightness applies hardware brightness immediately',
      () async {
        final mockMonitorService = MockMonitorServiceForLifecycle();
        final brightnessService = BrightnessService();

        final container = ProviderContainer(
          overrides: [
            monitorServiceProvider.overrideWithValue(mockMonitorService),
            brightnessServiceProvider.overrideWithValue(brightnessService),
          ],
        );
        addTearDown(container.dispose);

        await container.read(monitorListProvider.future);
        await container.read(settingsProvider.future);

        mockMonitorService.setBrightnessCalls.clear();
        // Calling setManualBrightness directly without circadianAdjustmentProvider active
        container
            .read(currentBrightnessProvider.notifier)
            .setManualBrightness(42.0);
        await Future<void>.delayed(const Duration(milliseconds: 800));

        expect(
          mockMonitorService.setBrightnessCalls.any(
            (c) => c['brightness'] == 42,
          ),
          isTrue,
          reason:
              'setManualBrightness must apply directly without depending on any background listener',
        );
      },
    );
  });
}
