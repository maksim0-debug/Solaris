import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/windows_power_listener.dart';

class MockMonitorService extends MonitorService {
  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async {
    return [
      MonitorInfo(
        id: r'\\.\DISPLAY1\Monitor0',
        name: 'LG 27GL850',
        friendlyName: 'LG UltraGear',
        deviceName: r'\\.\DISPLAY1\Monitor0',
        deviceIdHash: 'a1f9b2c3',
        isPrimary: true,
        realBrightness: 80,
        realTemperature: 5000,
      ),
    ];
  }
}

class FakeSettingsNotifier extends SettingsNotifier {
  final SettingsState customSettings;
  FakeSettingsNotifier(this.customSettings);

  @override
  Future<Map<String, SettingsState>> build() async {
    return {'all': customSettings};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyPosition = Position(
    latitude: 50.4495,
    longitude: 30.5253,
    timestamp: DateTime.now(),
    accuracy: 0,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );

  late ProviderContainer container;

  setUp(() {
    HttpOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return '.';
          },
        );

    final testSettings = SettingsState(
      isLocalIpcServerEnabled: true,
      apiAccessToken: 'test-token-123',
    );

    container = ProviderContainer(
      overrides: [
        locationStreamProvider.overrideWith(
          (ref) => Stream.value(dummyPosition),
        ),
        monitorServiceProvider.overrideWithValue(MockMonitorService()),
        settingsProvider.overrideWith(() => FakeSettingsNotifier(testSettings)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'WindowsPowerListener handles system suspend and resume sequences without errors',
    () async {
      final WindowsPowerListener powerListener = container.read(
        windowsPowerListenerProvider,
      );
      expect(powerListener.isSuspended, isFalse);

      // Simulate system suspend
      await powerListener.handleSystemSuspend();
      expect(powerListener.isSuspended, isTrue);

      // Simulate system resume
      await powerListener.handleSystemResume();
      expect(powerListener.isSuspended, isFalse);
    },
  );

  test(
    'WindowsPowerListener handles display change and hardware error events',
    () async {
      final WindowsPowerListener powerListener = container.read(
        windowsPowerListenerProvider,
      );

      expect(() => powerListener.handleDisplayChange(), returnsNormally);
      expect(
        () => powerListener.handleHardwareError(
          'DDC/CI I2C Bus NACK Error 0xC0262584',
        ),
        returnsNormally,
      );
    },
  );
}
