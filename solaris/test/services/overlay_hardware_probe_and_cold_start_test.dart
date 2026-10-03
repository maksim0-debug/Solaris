import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:solaris/services/temperature_service.dart';
import 'package:timezone/data/latest.dart' as tz;

class MockColdStartMonitorService extends MonitorService {
  final List<Map<String, dynamic>> setBrightnessCalls = [];
  final List<Map<String, dynamic>> getBrightnessCalls = [];

  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async {
    final asusDdc = await getBrightness(r'\\.\DISPLAY1', probeHardware: true);
    final lgDdc = await getBrightness(r'\\.\DISPLAY2', probeHardware: true);

    return [
      MonitorInfo(
        id: r'\\.\DISPLAY1',
        name: 'ASUS VG259QMR5A',
        friendlyName: 'ASUS VG259QMR5A',
        deviceName: r'\\.\DISPLAY1',
        deviceIdHash: 'hash_asus',
        isPrimary: true,
        realBrightness: 100,
        isDdcSupported: asusDdc != null,
      ),
      MonitorInfo(
        id: r'\\.\DISPLAY2',
        name: 'LG IPS224',
        friendlyName: 'LG IPS224',
        deviceName: r'\\.\DISPLAY2',
        deviceIdHash: 'hash_lg',
        isPrimary: false,
        realBrightness: 80,
        isDdcSupported: lgDdc != null,
      ),
    ];
  }

  @override
  Future<int?> getBrightness(
    String deviceName, {
    bool isOverlayOnly = false,
    bool probeHardware = false,
  }) async {
    getBrightnessCalls.add({
      'deviceName': deviceName,
      'isOverlayOnly': isOverlayOnly,
      'probeHardware': probeHardware,
    });
    // DISPLAY1 has no DDC/CI, DISPLAY2 has DDC/CI
    if (deviceName == r'\\.\DISPLAY1') {
      return null;
    }
    return 80;
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

class MockColdStorageService implements StorageService {
  final Map<String, String> data;
  MockColdStorageService(this.data);

  @override
  Future<String?> load(String filename) async => data[filename];

  @override
  Future<void> save(String filename, String content) async {
    data[filename] = content;
  }

  @override
  Future<void> clear(String filename) async {
    data.remove(filename);
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

  group('Cold Start Manual Brightness Restoration & Hardware Probe Tests', () {
    test(
      'Manual brightness (35%) is restored on cold start when auto-brightness is false',
      () async {
        SharedPreferences.setMockInitialValues({
          'auto_brightness_enabled': false,
          'last_known_brightness': 35.0,
          'manual_brightness': 35.0,
        });
        final prefs = await SharedPreferences.getInstance();

        final mockStorage = MockColdStorageService({
          'monitor_settings.json': jsonEncode({
            'all': SettingsState(isAutoBrightnessEnabled: false).toJson(),
          }),
        });

        final mockService = MockColdStartMonitorService();
        final brightnessService = BrightnessService();
        final tempService = TemperatureService();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            storageServiceProvider.overrideWithValue(mockStorage),
            monitorServiceProvider.overrideWithValue(mockService),
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

        // Simulate main.dart background listener
        container.listen<void>(circadianAdjustmentProvider, (_, _) {});

        // Await monitors & settings initialization
        await container.read(monitorListProvider.future);
        await container.read(settingsProvider.future);

        // Wait for smooth startup transition loop to complete
        for (int i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        // Verify hardware probing calls passed probeHardware: true
        expect(
          mockService.getBrightnessCalls.any((c) => c['probeHardware'] == true),
          isTrue,
        );

        // Verify both monitors were restored to saved manual brightness (35%) on cold startup
        final display1Calls = mockService.setBrightnessCalls
            .where((c) => c['device'] == r'\\.\DISPLAY1')
            .toList();
        final display2Calls = mockService.setBrightnessCalls
            .where((c) => c['device'] == r'\\.\DISPLAY2')
            .toList();

        expect(
          display1Calls,
          isNotEmpty,
          reason: 'Non-DDC DISPLAY1 must receive initial brightness on startup',
        );
        expect(display1Calls.last['brightness'], equals(35));
        expect(display1Calls.last['isOverlayOnly'], isTrue);

        expect(
          display2Calls,
          isNotEmpty,
          reason: 'DDC DISPLAY2 must receive initial brightness on startup',
        );
        expect(display2Calls.last['brightness'], equals(35));
        expect(display2Calls.last['isOverlayOnly'], isFalse);

        // Verify subsequent solar ticks do not cause redundant transition loops
        mockService.setBrightnessCalls.clear();
        for (int i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(mockService.setBrightnessCalls, isEmpty);
      },
    );
  });
}
