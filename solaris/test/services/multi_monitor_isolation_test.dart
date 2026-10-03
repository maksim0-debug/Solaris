import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/temperature_service.dart';
import 'package:timezone/data/latest.dart' as tz;

class MockMultiMonitorService extends MonitorService {
  final List<Map<String, dynamic>> setBrightnessCalls = [];

  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async {
    return [
      MonitorInfo(
        id: r'\\.\DISPLAY1',
        name: 'ASUS VG259QMR5A',
        friendlyName: 'ASUS VG259QMR5A',
        deviceName: r'\\.\DISPLAY1',
        deviceIdHash: 'hash_asus',
        isPrimary: true,
        realBrightness: 100,
        isDdcSupported: false,
      ),
      MonitorInfo(
        id: r'\\.\DISPLAY2',
        name: 'LG IPS224',
        friendlyName: 'LG IPS224',
        deviceName: r'\\.\DISPLAY2',
        deviceIdHash: 'hash_lg',
        isPrimary: false,
        realBrightness: 70,
        isDdcSupported: true,
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

  group('Multi-Monitor Brightness Isolation Tests (Zero Leakage)', () {
    late MockMultiMonitorService mockMonitorService;
    late BrightnessService brightnessService;
    late TemperatureService tempService;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      mockMonitorService = MockMultiMonitorService();
      brightnessService = BrightnessService();
      tempService = TemperatureService();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
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

      container.listen<void>(circadianAdjustmentProvider, (_, _) {});

      await container.read(monitorListProvider.future);
      await container.read(settingsProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      mockMonitorService.setBrightnessCalls.clear();
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'Scenario: Adjusting brightness on DISPLAY1 (non-DDC) updates ONLY DISPLAY1 and leaves DISPLAY2 untouched',
      () async {
        // Given: DISPLAY1 is selected
        container
            .read(selectedMonitorsProvider.notifier)
            .selectOnly(r'\\.\DISPLAY1');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        mockMonitorService.setBrightnessCalls.clear();

        // When: User adjusts manual brightness to 40%
        container
            .read(currentBrightnessProvider.notifier)
            .setManualBrightness(40.0);

        // Allow transition loop to complete
        for (int i = 0; i < 15; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        // Then: DISPLAY1 received brightness updates
        final display1Calls = mockMonitorService.setBrightnessCalls
            .where((c) => c['device'] == r'\\.\DISPLAY1')
            .toList();
        final display2Calls = mockMonitorService.setBrightnessCalls
            .where((c) => c['device'] == r'\\.\DISPLAY2')
            .toList();

        expect(display1Calls, isNotEmpty);
        expect(display1Calls.last['brightness'], equals(40));
        expect(display1Calls.last['isOverlayOnly'], isTrue);

        // Crucial verification: DISPLAY2 MUST NEVER receive any calls!
        expect(
          display2Calls,
          isEmpty,
          reason:
              'Adjusting DISPLAY1 must never leak brightness changes to DISPLAY2!',
        );
      },
    );

    test(
      'Scenario: Adjusting brightness on DISPLAY2 (DDC) updates ONLY DISPLAY2 and leaves DISPLAY1 untouched',
      () async {
        // Given: DISPLAY2 is selected
        container
            .read(selectedMonitorsProvider.notifier)
            .selectOnly(r'\\.\DISPLAY2');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        mockMonitorService.setBrightnessCalls.clear();

        // When: User adjusts manual brightness to 85%
        container
            .read(currentBrightnessProvider.notifier)
            .setManualBrightness(85.0);

        // Allow transition loop to complete
        for (int i = 0; i < 15; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        // Then: DISPLAY2 received brightness updates
        final display1Calls = mockMonitorService.setBrightnessCalls
            .where((c) => c['device'] == r'\\.\DISPLAY1')
            .toList();
        final display2Calls = mockMonitorService.setBrightnessCalls
            .where((c) => c['device'] == r'\\.\DISPLAY2')
            .toList();

        expect(display2Calls, isNotEmpty);
        expect(display2Calls.last['brightness'], equals(85));
        expect(display2Calls.last['isOverlayOnly'], isFalse);

        // Crucial verification: DISPLAY1 MUST NEVER receive any calls!
        expect(
          display1Calls,
          isEmpty,
          reason:
              'Adjusting DISPLAY2 must never leak brightness changes to DISPLAY1!',
        );
      },
    );

    test(
      'Scenario: Adjusting brightness when all is selected updates BOTH monitors with respective modes',
      () async {
        // Given: all is selected
        container.read(selectedMonitorsProvider.notifier).selectOnly('all');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        mockMonitorService.setBrightnessCalls.clear();

        // When: User adjusts manual brightness to 50%
        container
            .read(currentBrightnessProvider.notifier)
            .setManualBrightness(50.0);

        for (int i = 0; i < 15; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        final display1Calls = mockMonitorService.setBrightnessCalls
            .where((c) => c['device'] == r'\\.\DISPLAY1')
            .toList();
        final display2Calls = mockMonitorService.setBrightnessCalls
            .where((c) => c['device'] == r'\\.\DISPLAY2')
            .toList();

        expect(display1Calls, isNotEmpty);
        expect(display1Calls.last['brightness'], equals(50));
        expect(display1Calls.last['isOverlayOnly'], isTrue);

        expect(display2Calls, isNotEmpty);
        expect(display2Calls.last['brightness'], equals(50));
        expect(display2Calls.last['isOverlayOnly'], isFalse);
      },
    );
  });
}
