import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/sleep_provider.dart';

class TestSettingsNotifier extends SettingsNotifier {
  final SettingsState _initialSettings;

  TestSettingsNotifier(this._initialSettings);

  @override
  Future<Map<String, SettingsState>> build() async {
    return {'all': _initialSettings};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Anonymous Loopback Fallback & Multi-Key Scopes Test', () {
    late ProviderContainer container;
    late HttpClient client;
    late String serverUrl;

    setUp(() async {
      HttpOverrides.global = null;

      // 1. Scoped Key (index 0) has Read-Only Permissions (replaces previous index 0)
      final readOnlyKey = ApiKeyEntry.create(
        name: 'Scoped Read-Only Key',
        permissions: const ApiPermissionsConfig(isReadOnly: true),
      );

      // 2. Default Key (index 1) has Full Permissions
      final defaultKey = ApiKeyEntry.create(
        name: 'Default Key',
        permissions: const ApiPermissionsConfig(),
      );

      final settings = SettingsState(
        isLocalIpcServerEnabled: true,
        requireLocalToken: false,
        apiKeys: [readOnlyKey, defaultKey],
      );

      container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(() => TestSettingsNotifier(settings)),
        ],
      );

      final notifier = container.read(localIpcServiceProvider.notifier);
      await notifier.start();

      final state = container.read(localIpcServiceProvider);
      expect(state.isRunning, isTrue);

      serverUrl = 'http://127.0.0.1:${state.port}';
      client = HttpClient();
    });

    tearDown(() async {
      client.close();
      final notifier = container.read(localIpcServiceProvider.notifier);
      await notifier.stop();
      container.dispose();
    });

    test('Unauthenticated loopback request (OmniSleep) succeeds using default permissions even when FIRST key (index 0) is Read-Only', () async {
      final request = await client.postUrl(Uri.parse('$serverUrl/api/sleep/sessions'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode([
        {
          'id': 'omnisleep_session_1',
          'startTime': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
          'endTime': DateTime.now().toIso8601String(),
          'source': 'omnisleep',
        }
      ]));

      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.ok));

      final sleepSessions = container.read(sleepProvider).sessions;
      expect(sleepSessions.any((s) => s.id == 'omnisleep_session_1'), isTrue);
    });

    test('Authenticated request with Scoped Read-Only key token IS blocked with 403 Forbidden', () async {
      final settingsMap = container.read(settingsProvider).value;
      final readOnlyToken = settingsMap!['all']!.apiKeys[0].token;

      final request = await client.postUrl(Uri.parse('$serverUrl/api/sleep/sessions'));
      request.headers.contentType = ContentType.json;
      request.headers.set('X-API-Key', readOnlyToken);
      request.write(jsonEncode([
        {
          'id': 'omnisleep_session_2',
          'startTime': DateTime.now().subtract(const Duration(hours: 8)).toIso8601String(),
          'endTime': DateTime.now().toIso8601String(),
          'source': 'omnisleep',
        }
      ]));

      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.forbidden));
    });
  });
}
