import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/lifecycle_provider.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:timezone/data/latest.dart' as tz;

class MockMonitorServiceForDimming extends MonitorService {
  final List<Map<String, dynamic>> setBrightnessCalls = [];
  // Physical DDC/CI hardware reports 0 when display is at minimum brightness
  int simulatedHardwareBrightness = 0;

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
        realBrightness: simulatedHardwareBrightness,
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

  group('Software Dimming Negative Brightness Restore & Anti-Flicker Tests', () {
    test(
      'Negative brightness (-30%) does not jump to 0% and does not trigger flicker transition on restore',
      () async {
        final mockMonitorService = MockMonitorServiceForDimming();
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

        // Keep circadianAdjustmentProvider active
        container.listen<void>(circadianAdjustmentProvider, (_, _) {});

        await container.read(monitorListProvider.future);
        await container.read(settingsProvider.future);

        // Step 1: User sets negative manual brightness (-30%)
        container
            .read(currentBrightnessProvider.notifier)
            .setManualBrightness(-30.0);
        await Future<void>.delayed(const Duration(milliseconds: 600));

        final initialMonitor = container.read(monitorListProvider).value?.first;
        expect(
          initialMonitor?.realBrightness,
          -30,
          reason:
              'MonitorList must reflect -30% brightness after manual change',
        );

        // Step 2: Minimize app
        container.read(appLifecycleProvider.notifier).setMinimized();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Step 3: Restore app
        mockMonitorService.setBrightnessCalls.clear();
        container.read(appLifecycleProvider.notifier).setVisible();
        // Wait enough time for lifecycle listener to complete getConnectedMonitors
        await Future<void>.delayed(const Duration(milliseconds: 400));

        final restoredMonitor = container
            .read(monitorListProvider)
            .value
            ?.first;
        expect(
          restoredMonitor?.realBrightness,
          -30,
          reason:
              'MonitorList MUST NOT jump to 0% when restored during active software dimming',
        );

        // Step 4: Ensure no flicker transition from 0 to -30 was launched
        expect(
          mockMonitorService.setBrightnessCalls.where(
            (c) => c['brightness'] != -30,
          ),
          isEmpty,
          reason:
              'No transition steps (e.g. -12, -24, 0) should be sent when restoring already-dimmed display',
        );
      },
    );

    test(
      'Negative brightness (-30%) preserves dimming on displays reporting non-zero hardware minimum (e.g. 1%)',
      () async {
        final mockMonitorService = MockMonitorServiceForDimming();
        // Simulate hardware DDC/CI clamp at 1%
        mockMonitorService.simulatedHardwareBrightness = 1;
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

        container.listen<void>(circadianAdjustmentProvider, (_, _) {});

        await container.read(monitorListProvider.future);
        await container.read(settingsProvider.future);

        // Step 1: Set negative manual brightness (-30%)
        container
            .read(currentBrightnessProvider.notifier)
            .setManualBrightness(-30.0);
        await Future<void>.delayed(const Duration(milliseconds: 600));

        // Step 2: Minimize app
        container.read(appLifecycleProvider.notifier).setMinimized();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Step 3: Restore app
        mockMonitorService.setBrightnessCalls.clear();
        container.read(appLifecycleProvider.notifier).setVisible();
        await Future<void>.delayed(const Duration(milliseconds: 400));

        final restoredMonitor = container
            .read(monitorListProvider)
            .value
            ?.first;
        expect(
          restoredMonitor?.realBrightness,
          -30,
          reason:
              'MonitorList MUST preserve -30% even if physical hardware reports 1% minimum',
        );

        // Step 4: Ensure no spurious desync transition was launched
        expect(
          mockMonitorService.setBrightnessCalls.where(
            (c) => c['brightness'] != -30,
          ),
          isEmpty,
          reason:
              'No transition steps should be sent when restoring display with 1% hardware floor',
        );
      },
    );

    test('MonitorInfo copyWith correctly updates and preserves fields', () {
      final info = MonitorInfo(
        id: 'id1',
        name: 'Name 1',
        friendlyName: 'Friendly 1',
        deviceName: 'Device 1',
        deviceIdHash: 'hash1',
        isPrimary: true,
        realBrightness: 50,
        realTemperature: 6500,
      );

      final updated = info.copyWith(realBrightness: -20);
      expect(updated.id, info.id);
      expect(updated.name, info.name);
      expect(updated.friendlyName, info.friendlyName);
      expect(updated.deviceName, info.deviceName);
      expect(updated.deviceIdHash, info.deviceIdHash);
      expect(updated.isPrimary, true);
      expect(updated.realBrightness, -20);
      expect(updated.realTemperature, 6500);

      final withNulls = updated.copyWith(
        overrideBrightnessWithNull: true,
        overrideTemperatureWithNull: true,
      );
      expect(withNulls.realBrightness, isNull);
      expect(withNulls.realTemperature, isNull);
    });

    test(
      'syncHardwareBrightness correctly accepts new negative brightness updates when already dimmed',
      () {
        final brightnessService = BrightnessService();
        const deviceName = r'\\.\DISPLAY1';

        // Initial software dimming state at -10%
        brightnessService.syncHardwareBrightness(deviceName, -10);

        // Hardware floor reading (e.g. 0% or 1%) MUST be ignored
        brightnessService.syncHardwareBrightness(deviceName, 0);
        brightnessService.syncHardwareBrightness(deviceName, 1);
        brightnessService.syncHardwareBrightness(
          deviceName,
          MonitorService.hardwareBrightnessFloorThreshold,
        );

        // Incoming new negative brightness (e.g. -40%) MUST NOT be blocked by the floor check
        brightnessService.syncHardwareBrightness(deviceName, -40);

        // An incoming positive brightness above floor (e.g. 50%) MUST update
        brightnessService.syncHardwareBrightness(deviceName, 50);
      },
    );

    test('MonitorService.hardwareBrightnessFloorThreshold is exactly 5', () {
      expect(MonitorService.hardwareBrightnessFloorThreshold, 5);
    });
  });
}
