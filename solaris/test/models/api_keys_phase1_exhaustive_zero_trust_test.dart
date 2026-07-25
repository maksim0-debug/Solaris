import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/utils/key_obfuscator.dart';

void main() {
  group('Phase 1 - Zero-Trust Exhaustive Audit Suite: ApiKeyEntry & Data Models', () {
    group('A. BDD Behavioral Specifications (Given / When / Then)', () {
      test('Scenario 1: Given a new ApiKeyEntry, When created with custom name, Then name is trimmed and secure token is generated', () {
        final entry = ApiKeyEntry.create(
          name: '   Home Assistant Gateway   ',
          permissions: const ApiPermissionsConfig(isReadOnly: true),
        );

        expect(entry.name, equals('Home Assistant Gateway'));
        expect(entry.id, isNotEmpty);
        expect(entry.token.startsWith('sol_sec_'), isTrue);
        expect(entry.token.length, equals(72)); // sol_sec_ (8) + 64 hex chars
        expect(entry.permissions.isReadOnly, isTrue);
        expect(entry.isDpapiFallback, isFalse);
        expect(entry.lastUsedAt, isNull);
      });

      test('Scenario 2: Given corrupted DPAPI token in JSON, When ApiKeyEntry.fromJson is called, Then graceful fallback triggers with isDpapiFallback=true', () {
        final corruptedJson = {
          'id': 'test_corrupt_id',
          'name': 'Corrupted Key',
          'token': 'dpapi:corrupted_base64_payload_that_cannot_be_decrypted!!!',
          'permissions': const ApiPermissionsConfig().toJson(),
          'createdAt': DateTime.now().toIso8601String(),
          'isDpapiFallback': false,
        };

        final entry = ApiKeyEntry.fromJson(corruptedJson);

        expect(entry.id, equals('test_corrupt_id'));
        expect(entry.name, equals('Corrupted Key'));
        expect(entry.token.startsWith('sol_sec_'), isTrue);
        expect(entry.token.length, equals(72));
        expect(entry.isDpapiFallback, isTrue);
      });

      test('Scenario 3: Given legacy SettingsState JSON without apiKeys, When deserialized, Then automatic migration creates Default Key with legacy token', () {
        final rawToken = 'sol_sec_11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff';
        final encryptedToken = KeyObfuscator.encrypt(rawToken);
        final customPermissions = const ApiPermissionsConfig(
          isReadOnly: true,
          allowReadMonitors: false,
        );

        final legacyJson = {
          'apiAccessToken': encryptedToken,
          'apiPermissions': customPermissions.toJson(),
          'requireLocalToken': true,
        };

        final settings = SettingsState.fromJson(legacyJson);

        expect(settings.apiKeys.length, equals(1));
        expect(settings.apiKeys.first.name, equals('Default Key'));
        expect(settings.apiKeys.first.token, equals(rawToken));
        expect(settings.apiKeys.first.permissions, equals(customPermissions));
        expect(settings.apiAccessToken, equals(rawToken));
        expect(settings.apiPermissions, equals(customPermissions));
        expect(settings.requireLocalToken, isTrue);
      });

      test('Scenario 4: Given empty apiKeys list in JSON, When SettingsState.fromJson parses, Then starter key is created to enforce non-empty invariant', () {
        final emptyJson = <String, dynamic>{
          'apiKeys': <Map<String, dynamic>>[],
          'requireLocalToken': false,
        };

        final settings = SettingsState.fromJson(emptyJson);

        expect(settings.apiKeys.isNotEmpty, isTrue);
        expect(settings.apiKeys.length, equals(1));
        expect(settings.apiKeys.first.name, equals('Default Key'));
      });
    });

    group('B. Edge Cases & Defensive Realism Audit', () {
      test('1. Malformed fields in ApiKeyEntry.fromJson do not cause unhandled crashes', () {
        final malformedJson = <String, dynamic>{
          'id': null,
          'name': null,
          'token': null,
          'permissions': 'not_a_map',
          'createdAt': 'invalid_date_string',
          'lastUsedAt': 'invalid_date_string',
          'isDpapiFallback': 'not_a_bool',
        };

        final entry = ApiKeyEntry.fromJson(malformedJson);

        expect(entry.id, isNotEmpty);
        expect(entry.name, equals('API Key'));
        expect(entry.token.startsWith('sol_sec_'), isTrue);
        expect(entry.permissions, equals(const ApiPermissionsConfig()));
        expect(entry.createdAt, isA<DateTime>());
        expect(entry.lastUsedAt, isNull);
        expect(entry.isDpapiFallback, isFalse);
      });

      test('2. SettingsState.fromJson handles mixed invalid elements in apiKeys list gracefully', () {
        final validKey = ApiKeyEntry.create(name: 'Valid Key');
        final mixedJson = {
          'apiKeys': [
            null,
            12345,
            'invalid_string',
            validKey.toJson(),
            <String, dynamic>{'invalid': 'object_without_token'},
          ],
        };

        final settings = SettingsState.fromJson(mixedJson);

        expect(settings.apiKeys.isNotEmpty, isTrue);
        final found = settings.apiKeys.where((k) => k.name == 'Valid Key').toList();
        expect(found.length, equals(1));
      });

      test('3. SettingsState.apiKeys list is strictly unmodifiable (Immutability Check)', () {
        final settings = SettingsState();
        expect(
          () => (settings.apiKeys as List).add(ApiKeyEntry.create(name: 'Hack')),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('4. Zero Secret Leakage: ApiKeyEntry.toJson encrypts token so raw secret never appears in plain text', () {
        final rawSecretToken = ApiKeyEntry.generateSecureToken();
        final entry = ApiKeyEntry(
          id: 'sec_test_id',
          name: 'Security Test Key',
          token: rawSecretToken,
          permissions: const ApiPermissionsConfig(),
          createdAt: DateTime.now(),
        );

        final jsonMap = entry.toJson();
        final jsonString = jsonMap.toString();

        expect(jsonMap['token'], isNot(equals(rawSecretToken)));
        expect(jsonString.contains(rawSecretToken), isFalse);
      });

      test('5. copyWith supports both multi-key updating and legacy parameter overrides', () {
        final key1 = ApiKeyEntry.create(name: 'Key One');
        final key2 = ApiKeyEntry.create(name: 'Key Two');
        final initial = SettingsState(apiKeys: [key1, key2]);

        // Legacy override test
        final updatedLegacy = initial.copyWith(
          apiAccessToken: 'sol_sec_override_token_1234567890123456789012345678901234567890123456',
        );

        expect(updatedLegacy.apiKeys.length, equals(2));
        expect(updatedLegacy.apiKeys.first.token, equals('sol_sec_override_token_1234567890123456789012345678901234567890123456'));
        expect(updatedLegacy.apiKeys.last.name, equals('Key Two'));

        // Multi-key replace test
        final key3 = ApiKeyEntry.create(name: 'Key Three');
        final updatedList = initial.copyWith(apiKeys: [key3]);
        expect(updatedList.apiKeys.length, equals(1));
        expect(updatedList.apiKeys.first.name, equals('Key Three'));
      });
    });

    group('C. Property-Based Testing (PBT) & Invariants Audit', () {
      test('PBT Invariant 1: 100 generated tokens strictly follow sol_sec_[0-9a-fA-F]{64} format', () {
        final hexRegex = RegExp(r'^sol_sec_[0-9a-fA-F]{64}$');
        for (int i = 0; i < 100; i++) {
          final token = ApiKeyEntry.generateSecureToken();
          expect(token.length, equals(72), reason: 'Iteration $i failed length check');
          expect(hexRegex.hasMatch(token), isTrue, reason: 'Iteration $i failed regex check');
        }
      });

      test('PBT Invariant 2: SettingsState.apiKeys is NEVER empty across 50 random serialization roundtrips', () {
        final random = Random(42);
        for (int i = 0; i < 50; i++) {
          final keysCount = random.nextInt(5);
          final keys = List.generate(keysCount, (idx) => ApiKeyEntry.create(name: 'Key $idx'));
          final state = SettingsState(
            apiKeys: keys,
            requireLocalToken: random.nextBool(),
          );

          final serialized = state.toJson();
          final restored = SettingsState.fromJson(serialized);

          expect(restored.apiKeys.isNotEmpty, isTrue, reason: 'Iteration $i produced empty apiKeys');
          expect(restored.requireLocalToken, equals(state.requireLocalToken));
        }
      });

      test('PBT Invariant 3: Serialization/Deserialization Roundtrip Equality for ApiKeyEntry', () {
        final permissions = const ApiPermissionsConfig(
          isReadOnly: true,
          allowReadMonitors: false,
          allowReadCircadian: true,
        );
        final entry = ApiKeyEntry(
          id: 'pbt_roundtrip_id',
          name: 'PBT Roundtrip Key',
          token: 'sol_sec_00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff',
          permissions: permissions,
          createdAt: DateTime(2026, 7, 25, 10, 0, 0),
          lastUsedAt: DateTime(2026, 7, 25, 10, 20, 0),
          isDpapiFallback: false,
        );

        final json = entry.toJson();
        final restored = ApiKeyEntry.fromJson(json);

        expect(restored, equals(entry));
        expect(restored.hashCode, equals(entry.hashCode));
      });
    });
  });
}
