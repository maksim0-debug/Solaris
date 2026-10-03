import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/temperature_service.dart';
import 'package:timezone/data/latest.dart' as tz;

class DualMonitorReproService extends MonitorService {
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
        realBrightness: 0,
        isDdcSupported: false,
      ),
      MonitorInfo(
        id: r'\\.\DISPLAY2',
        name: 'LG IPS224',
        friendlyName: 'LG IPS224',
        deviceName: r'\\.\DISPLAY2',
        deviceIdHash: 'hash_lg',
        isPrimary: false,
        realBrightness: 50,
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

  test(
    'Repro: Auto Brightness transition for overlay-only primary monitor',
    () async {
      final mockMonitorService = DualMonitorReproService();
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

      container.listen<void>(circadianAdjustmentProvider, (_, _) {});

      await container.read(monitorListProvider.future);
      await container.read(settingsProvider.future);

      // Initial settle
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // 1. User sets manual brightness to 67%
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(false);
      container
          .read(currentBrightnessProvider.notifier)
          .setManualBrightness(67.0);
      await Future<void>.delayed(const Duration(milliseconds: 800));

      mockMonitorService.setBrightnessCalls.clear();

      // 2. User enables Auto Brightness
      container
          .read(autoBrightnessAdjustmentProvider.notifier)
          .setEnabled(true);

      // Let transition run for 2 seconds
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final asusCalls = mockMonitorService.setBrightnessCalls
          .where((c) => c['device'] == r'\\.\DISPLAY1')
          .map((c) => c['brightness'] as int)
          .toList();
      final lgCalls = mockMonitorService.setBrightnessCalls
          .where((c) => c['device'] == r'\\.\DISPLAY2')
          .map((c) => c['brightness'] as int)
          .toList();

      // Both should reach target auto brightness (> 75%)
      expect(asusCalls.last, greaterThan(75));
      expect(lgCalls.last, greaterThan(75));
    },
  );
}
