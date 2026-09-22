import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/temperature_provider.dart';
import 'package:solaris/services/api_control_handler.dart';
import 'package:solaris/services/api_monitors_handler.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/services/monitor_slug_resolver.dart';
import 'package:solaris/services/temperature_service.dart';

class MockMonitorService extends Fake implements MonitorService {
  final List<MonitorInfo> _monitors;
  MockMonitorService(this._monitors);

  @override
  Future<List<MonitorInfo>> getConnectedMonitors() async => _monitors;

  @override
  Future<bool> setMonitorTemperature(String deviceName, int kelvin) async =>
      true;

  @override
  Future<bool> resetMonitorTemperature(String deviceName) async => true;
}

class FakeMonitorListNotifier extends MonitorListNotifier {
  final List<MonitorInfo> _monitors;
  FakeMonitorListNotifier(this._monitors);

  @override
  Future<List<MonitorInfo>> build() async => _monitors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Extended Warmth REST API & Settings Integration Tests', () {
    late ProviderContainer container;
    late HttpServer server;
    late ApiRouter router;
    late HttpClient client;
    late String serverUrl;

    final mockMonitors = [
      MonitorInfo(
        id: r'\\.\DISPLAY1',
        name: 'Generic PnP Monitor',
        deviceName: r'\\.\DISPLAY1',
        friendlyName: 'Primary Monitor',
        deviceIdHash: 'hash1',
        isPrimary: true,
      ),
    ];

    setUp(() async {
      HttpOverrides.global = null;
      container = ProviderContainer(
        overrides: [
          monitorServiceProvider.overrideWithValue(
            MockMonitorService(mockMonitors),
          ),
          monitorListProvider.overrideWith(
            () => FakeMonitorListNotifier(mockMonitors),
          ),
          locationStreamProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://localhost:${server.port}';

      router = ApiRouter();
      final controlHandler = ApiControlHandler(container);
      final monitorsHandler = ApiMonitorsHandler(container);

      router.post(
        '/api/v1/control',
        (req, params) => controlHandler.handleControl(req, params),
      );
      router.post(
        '/api/v1/monitors/:slug/temperature',
        (req, params) =>
            monitorsHandler.handleSetMonitorTemperature(req, params),
      );

      server.listen((HttpRequest request) async {
        final handled = await router.handle(request);
        if (!handled) {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found');
          await request.response.close();
        }
      });

      client = HttpClient();
      await container.read(settingsProvider.future);
      await container.read(monitorListProvider.future);
      await container.read(temperatureSettingsProvider.future);
      MonitorSlugResolver.updateMonitors(mockMonitors);
    });

    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      client.close(force: true);
      await server.close(force: true);
      container.dispose();
    });

    test(
      'POST /api/v1/control set_temperature accepts 1000K..6500K natively',
      () async {
        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/control'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'action': 'set_temperature', 'value': 2000}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.accepted));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        expect(json['status'], equals('accepted'));
        expect(json['action'], equals('set_temperature'));
        expect(json['queued']['value'], equals(2000));

        final tempStateMap = container.read(temperatureSettingsProvider).value;
        expect(tempStateMap?['all']?.manualTemperature, equals(2000));
        expect(tempStateMap?['all']?.isEnabled, isFalse);
        expect(container.read(manualTemperatureProvider), equals(2000));
      },
    );

    test('POST /api/v1/control set_temperature rejects < 1000K', () async {
      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'action': 'set_temperature', 'value': 900}));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.badRequest));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['title'], equals('Validation Error'));
      expect(json['detail'], contains('between 1000 and 6500'));
    });

    test('POST /api/v1/control set_temperature rejects > 6500K', () async {
      final req = await client.postUrl(Uri.parse('$serverUrl/api/v1/control'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'action': 'set_temperature', 'value': 7000}));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.badRequest));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['title'], equals('Validation Error'));
      expect(json['detail'], contains('between 1000 and 6500'));
    });

    test(
      'POST /api/v1/monitors/:slug/temperature accepts < 3300K down to 1000K natively',
      () async {
        final req = await client.postUrl(
          Uri.parse('$serverUrl/api/v1/monitors/primary-monitor/temperature'),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'value': 1800}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.accepted));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        expect(json['status'], equals('accepted'));
        expect(json['queued']['value'], equals(1800));

        final tempStateMap = container.read(temperatureSettingsProvider).value;
        expect(tempStateMap?[r'\\.\DISPLAY1']?.manualTemperature, equals(1800));
        expect(tempStateMap?[r'\\.\DISPLAY1']?.isEnabled, isFalse);
      },
    );

    test('POST /api/v1/monitors/:slug/temperature rejects < 1000K', () async {
      final req = await client.postUrl(
        Uri.parse('$serverUrl/api/v1/monitors/primary-monitor/temperature'),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'value': 800}));
      final resp = await req.close();

      expect(resp.statusCode, equals(HttpStatus.badRequest));
      final bodyStr = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(bodyStr);
      expect(json['title'], equals('Validation Error'));
      expect(json['detail'], contains('between 1000 and 6500'));
    });

    test(
      'POST /api/v1/monitors/:slug/temperature returns 404 for unknown monitor slug',
      () async {
        final req = await client.postUrl(
          Uri.parse(
            '$serverUrl/api/v1/monitors/non-existent-screen/temperature',
          ),
        );
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'value': 2500}));
        final resp = await req.close();

        expect(resp.statusCode, equals(HttpStatus.notFound));
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        expect(json['title'], equals('Monitor Not Found'));
        expect(json['status'], equals(404));
      },
    );

    test(
      'Manual temperature allows setting 1000K natively without snapping',
      () async {
        container.read(manualTemperatureProvider.notifier).setTemperature(1000);
        expect(container.read(manualTemperatureProvider), equals(1000));
      },
    );

    test(
      'TemperatureService updates target monitor independently when specific monitor selected, and all monitors when "all" selected',
      () async {
        final tempService = TemperatureService();
        final monitors = [
          MonitorInfo(
            id: r'\\.\DISPLAY1',
            name: 'Monitor 1',
            deviceName: r'\\.\DISPLAY1',
            friendlyName: 'Primary Monitor',
            deviceIdHash: 'hash1',
            isPrimary: true,
          ),
          MonitorInfo(
            id: r'\\.\DISPLAY2',
            name: 'Monitor 2',
            deviceName: r'\\.\DISPLAY2',
            friendlyName: 'Secondary Monitor',
            deviceIdHash: 'hash2',
            isPrimary: false,
          ),
        ];

        final updatedTemperatures = <String, int>{};
        final mockService = MockMonitorService(monitors);

        // Call with single monitor selection: only target monitor is updated
        await tempService.setTemperatureInstant(
          selection: r'\\.\DISPLAY2',
          targetValue: 2000,
          monitors: monitors,
          monitorService: mockService,
          updateTemperatureCallback: (id, val) {
            updatedTemperatures[id] = val;
          },
        );

        expect(updatedTemperatures.containsKey(r'\\.\DISPLAY1'), isFalse);
        expect(updatedTemperatures[r'\\.\DISPLAY2'], equals(2000));

        // Call with 'all' selection: all monitors are updated
        await tempService.setTemperatureInstant(
          selection: 'all',
          targetValue: 3000,
          monitors: monitors,
          monitorService: mockService,
          updateTemperatureCallback: (id, val) {
            updatedTemperatures[id] = val;
          },
        );

        expect(updatedTemperatures[r'\\.\DISPLAY1'], equals(3000));
        expect(updatedTemperatures[r'\\.\DISPLAY2'], equals(3000));

        // Test resetNow with single monitor selection: only target is reset
        await tempService.resetTemperatureNow(
          selection: r'\\.\DISPLAY1',
          monitors: monitors,
          monitorService: mockService,
          updateTemperatureCallback: (id, val) {
            updatedTemperatures[id] = val;
          },
        );

        expect(updatedTemperatures[r'\\.\DISPLAY1'], equals(6500));
        expect(updatedTemperatures[r'\\.\DISPLAY2'], equals(3000));

        // Test resetNow with 'all' selection: all monitors are reset
        await tempService.resetTemperatureNow(
          selection: 'all',
          monitors: monitors,
          monitorService: mockService,
          updateTemperatureCallback: (id, val) {
            updatedTemperatures[id] = val;
          },
        );

        expect(updatedTemperatures[r'\\.\DISPLAY1'], equals(6500));
        expect(updatedTemperatures[r'\\.\DISPLAY2'], equals(6500));
      },
    );

    test(
      'TemperatureService trailing edge timer dispatches final target on rapid drag',
      () async {
        final tempService = TemperatureService();
        final monitors = [
          MonitorInfo(
            id: r'\\.\DISPLAY1',
            name: 'Monitor 1',
            deviceName: r'\\.\DISPLAY1',
            friendlyName: 'Primary Monitor',
            deviceIdHash: 'hash1',
            isPrimary: true,
          ),
        ];

        int lastNativeSent = 0;
        final recordingService = _RecordingMonitorService(monitors, (kelvin) {
          lastNativeSent = kelvin;
        });

        // Call twice rapidly (< 20ms)
        await tempService.setTemperatureInstant(
          selection: 'all',
          targetValue: 2500,
          monitors: monitors,
          monitorService: recordingService,
          updateTemperatureCallback: (_, _) {},
        );
        expect(lastNativeSent, equals(2500));

        // Immediate second call should be throttled, scheduling trailing timer
        await tempService.setTemperatureInstant(
          selection: 'all',
          targetValue: 1800,
          monitors: monitors,
          monitorService: recordingService,
          updateTemperatureCallback: (_, _) {},
        );
        // Has not fired immediately
        expect(lastNativeSent, equals(2500));

        // Wait 35ms for trailing timer
        await Future<void>.delayed(const Duration(milliseconds: 35));
        expect(lastNativeSent, equals(1800));
      },
    );

    test(
      'applyTemperatureSmoothly updates _currentHardwareTemperature across all monitors',
      () async {
        final tempService = TemperatureService();
        final monitors = [
          MonitorInfo(
            id: r'\\.\DISPLAY1',
            name: 'Monitor 1',
            deviceName: r'\\.\DISPLAY1',
            friendlyName: 'Primary Monitor',
            deviceIdHash: 'hash1',
            isPrimary: true,
          ),
          MonitorInfo(
            id: r'\\.\DISPLAY2',
            name: 'Monitor 2',
            deviceName: r'\\.\DISPLAY2',
            friendlyName: 'Secondary Monitor',
            deviceIdHash: 'hash2',
            isPrimary: false,
          ),
        ];

        final mockService = MockMonitorService(monitors);

        tempService.applyTemperatureSmoothly(
          selection: 'all',
          targetValue: 2200,
          monitors: monitors,
          monitorService: mockService,
          updateTemperatureCallback: (_, _) {},
          isUIVisible: false,
        );

        // Allow event loop to run transition iteration
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Hardware cache must be updated for all monitors, not just the primary
        expect(
          tempService.currentHardwareTemperature[r'\\.\DISPLAY1'],
          equals(2200),
        );
        expect(
          tempService.currentHardwareTemperature[r'\\.\DISPLAY2'],
          equals(2200),
        );
      },
    );

    test(
      'Disabling auto temperature restores last manual temperature on hardware and state',
      () async {
        final notifier = container.read(temperatureSettingsProvider.notifier);
        // Set manual temperature to 4200K
        container
            .read(currentTemperatureProvider.notifier)
            .setManualTemperature(4200);
        expect(container.read(currentTemperatureProvider), equals(4200));

        // Enable auto temperature
        notifier.setEnabled(true);
        final stateAfterEnable = container
            .read(temperatureSettingsProvider)
            .value;
        expect(stateAfterEnable?['all']?.isEnabled, isTrue);

        // Disable auto temperature -> must restore 4200K
        notifier.setEnabled(false);
        final stateAfterDisable = container
            .read(temperatureSettingsProvider)
            .value;
        expect(stateAfterDisable?['all']?.isEnabled, isFalse);
        expect(container.read(currentTemperatureProvider), equals(4200));
      },
    );

    test(
      'Manual temperature on specific monitor does not overwrite other monitors and preserves 6500K',
      () async {
        final notifier = container.read(temperatureSettingsProvider.notifier);
        // Set DISPLAY1 to 2200K
        notifier.setManualTemperature(2200, monitorId: r'\\.\DISPLAY1');

        var tempMap = container.read(temperatureSettingsProvider).value;
        expect(tempMap?[r'\\.\DISPLAY1']?.manualTemperature, equals(2200));
        expect(tempMap?['all']?.manualTemperature, isNull);

        // Explicitly set DISPLAY1 to 6500K: must persist as 6500K rather than snapping or resetting
        notifier.setManualTemperature(6500, monitorId: r'\\.\DISPLAY1');
        tempMap = container.read(temperatureSettingsProvider).value;
        expect(tempMap?[r'\\.\DISPLAY1']?.manualTemperature, equals(6500));
        expect(tempMap?['all']?.manualTemperature, isNull);
      },
    );

    test(
      'ManualTemperatureNotifier.update() synchronizes value without disabling auto-temperature',
      () async {
        final notifier = container.read(temperatureSettingsProvider.notifier);
        notifier.setEnabled(true);
        expect(
          container.read(temperatureSettingsProvider).value?['all']?.isEnabled,
          isTrue,
        );

        // Call update() as happens when clicking a monitor tab
        container.read(manualTemperatureProvider.notifier).update(2800);
        expect(container.read(manualTemperatureProvider), equals(2800));

        // Auto-temperature must remain enabled!
        expect(
          container.read(temperatureSettingsProvider).value?['all']?.isEnabled,
          isTrue,
        );
      },
    );

    test(
      'TemperatureService.setTemperatureInstant() deduplicates when already at target',
      () async {
        final tempService = TemperatureService();
        int callCount = 0;
        final recordingService = _RecordingMonitorService(mockMonitors, (_) {
          callCount++;
        });

        // First call applies target 3500K
        await tempService.setTemperatureInstant(
          selection: r'\\.\DISPLAY1',
          targetValue: 3500,
          monitors: mockMonitors,
          monitorService: recordingService,
          updateTemperatureCallback: (_, _) {},
        );
        expect(callCount, equals(1));

        // Second call with same target should be deduplicated and avoid native call
        await tempService.setTemperatureInstant(
          selection: r'\\.\DISPLAY1',
          targetValue: 3500,
          monitors: mockMonitors,
          monitorService: recordingService,
          updateTemperatureCallback: (_, _) {},
        );
        expect(callCount, equals(1)); // Still 1!
      },
    );

    test(
      'TemperatureSettingsNotifier.syncAllMonitorsToGlobal() preserves monitor isEnabled and manualTemperature',
      () async {
        final notifier = container.read(temperatureSettingsProvider.notifier);

        // Customize DISPLAY1 with individual manualTemperature and isEnabled = false
        notifier.setManualTemperature(2400, monitorId: r'\\.\DISPLAY1');
        var stateMap = container.read(temperatureSettingsProvider).value;
        expect(stateMap?[r'\\.\DISPLAY1']?.manualTemperature, equals(2400));
        expect(stateMap?[r'\\.\DISPLAY1']?.isEnabled, isFalse);

        // Sync to global
        notifier.syncAllMonitorsToGlobal();

        // Presets should be synced, but manualTemperature and isEnabled are preserved!
        stateMap = container.read(temperatureSettingsProvider).value;
        expect(stateMap?[r'\\.\DISPLAY1']?.manualTemperature, equals(2400));
        expect(stateMap?[r'\\.\DISPLAY1']?.isEnabled, isFalse);
      },
    );
  });
}

class _RecordingMonitorService extends MockMonitorService {
  final void Function(int) onSetTemperature;
  _RecordingMonitorService(super.monitors, this.onSetTemperature);

  @override
  Future<bool> setMonitorTemperature(String deviceName, int kelvin) async {
    onSetTemperature(kelvin);
    return true;
  }
}
