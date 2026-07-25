import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/utils/key_obfuscator.dart';

void main() {
  group('ApiKeyEntry Unit Tests', () {
    test('generateSecureToken produces sol_sec_ prefix with 64 hex characters', () {
      final token = ApiKeyEntry.generateSecureToken();
      expect(token.startsWith('sol_sec_'), isTrue);
      final hexPart = token.substring(8);
      expect(hexPart.length, equals(64));
      expect(RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hexPart), isTrue);
    });

    test('ApiKeyEntry.create initializes with generated ID, secure token, and defaults', () {
      final entry = ApiKeyEntry.create(name: '  Home Assistant  ');
      expect(entry.name, equals('Home Assistant'));
      expect(entry.id, isNotEmpty);
      expect(entry.token.startsWith('sol_sec_'), isTrue);
      expect(entry.permissions, equals(const ApiPermissionsConfig()));
      expect(entry.isDpapiFallback, isFalse);
      expect(entry.lastUsedAt, isNull);
    });

    test('ApiKeyEntry.create falls back to default name when name is empty', () {
      final entry = ApiKeyEntry.create(name: '   ', defaultIndex: 3);
      expect(entry.name, equals('API Key 3'));
    });

    test('toJson and fromJson serialize and deserialize with KeyObfuscator token encryption', () {
      final permissions = const ApiPermissionsConfig(
        isReadOnly: true,
        allowReadMonitors: false,
      );
      final original = ApiKeyEntry(
        id: 'key_123',
        name: 'Stream Deck',
        token: 'sol_sec_abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        permissions: permissions,
        createdAt: DateTime(2026, 7, 25, 10, 0, 0),
        lastUsedAt: DateTime(2026, 7, 25, 10, 15, 0),
        isDpapiFallback: false,
      );

      final json = original.toJson();
      expect(json['id'], equals('key_123'));
      expect(json['name'], equals('Stream Deck'));
      expect(json['token'], isNot(equals(original.token))); // Encrypted token
      expect(json['isDpapiFallback'], isFalse);

      final restored = ApiKeyEntry.fromJson(json);
      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.token, equals(original.token)); // Decrypted back
      expect(restored.permissions, equals(permissions));
      expect(restored.isDpapiFallback, isFalse);
    });

    test('ApiKeyEntry.fromJson gracefully recovers from invalid/corrupted token payload', () {
      final badJson = {
        'id': 'corrupted_key_1',
        'name': 'Broken Key',
        'token': 'dpapi:invalid_encrypted_data_that_fails_decryption!!!',
        'permissions': const ApiPermissionsConfig().toJson(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      final restored = ApiKeyEntry.fromJson(badJson);
      expect(restored.id, equals('corrupted_key_1'));
      expect(restored.name, equals('Broken Key'));
      expect(restored.token.startsWith('sol_sec_'), isTrue); // Generated fallback
      expect(restored.isDpapiFallback, isTrue); // Flag set to true
    });

    test('copyWith updates specified properties while preserving unassigned ones', () {
      final key = ApiKeyEntry.create(name: 'Original');
      final newPermissions = const ApiPermissionsConfig(isReadOnly: true);
      final lastUsed = DateTime.now();

      final updated = key.copyWith(
        name: 'Renamed',
        permissions: newPermissions,
        lastUsedAt: lastUsed,
        isDpapiFallback: true,
      );

      expect(updated.id, equals(key.id));
      expect(updated.name, equals('Renamed'));
      expect(updated.token, equals(key.token));
      expect(updated.permissions, equals(newPermissions));
      expect(updated.lastUsedAt, equals(lastUsed));
      expect(updated.isDpapiFallback, isTrue);
    });

    test('Equality operator and hashCode work accurately', () {
      final now = DateTime.now();
      final key1 = ApiKeyEntry(
        id: '1',
        name: 'Key',
        token: 'token',
        permissions: const ApiPermissionsConfig(),
        createdAt: now,
      );
      final key2 = ApiKeyEntry(
        id: '1',
        name: 'Key',
        token: 'token',
        permissions: const ApiPermissionsConfig(),
        createdAt: now,
      );
      final key3 = key1.copyWith(name: 'Other');

      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
      expect(key1, isNot(equals(key3)));
    });
  });

  group('SettingsState Multi-Key Migration & Serialization Tests', () {
    test('Default SettingsState contains 1 Default Key in apiKeys list', () {
      final settings = SettingsState();
      expect(settings.apiKeys.length, equals(1));
      expect(settings.apiKeys.first.name, equals('Default Key'));
      expect(settings.apiAccessToken, equals(settings.apiKeys.first.token));
      expect(settings.apiPermissions, equals(settings.apiKeys.first.permissions));
      expect(settings.requireLocalToken, isFalse);
    });

    test('SettingsState.fromJson migrates legacy apiAccessToken and apiPermissions', () {
      final rawLegacyToken = 'sol_sec_legacy_token_12345678901234567890123456789012345678901234567890';
      final encryptedLegacyToken = KeyObfuscator.encrypt(rawLegacyToken);
      final legacyPermissions = const ApiPermissionsConfig(
        isReadOnly: true,
        allowReadMonitors: false,
      );

      final legacyJson = {
        'apiAccessToken': encryptedLegacyToken,
        'apiPermissions': legacyPermissions.toJson(),
        'requireLocalToken': true,
      };

      final migrated = SettingsState.fromJson(legacyJson);
      expect(migrated.apiKeys.length, equals(1));
      final migratedKey = migrated.apiKeys.first;
      expect(migratedKey.name, equals('Default Key'));
      expect(migratedKey.token, equals(rawLegacyToken));
      expect(migratedKey.permissions, equals(legacyPermissions));
      expect(migrated.apiAccessToken, equals(rawLegacyToken));
      expect(migrated.apiPermissions, equals(legacyPermissions));
      expect(migrated.requireLocalToken, isTrue);
    });

    test('SettingsState.fromJson parses multiple apiKeys correctly', () {
      final key1 = ApiKeyEntry.create(name: 'Key 1');
      final key2 = ApiKeyEntry.create(name: 'Key 2');

      final json = {
        'apiKeys': [key1.toJson(), key2.toJson()],
        'requireLocalToken': false,
      };

      final settings = SettingsState.fromJson(json);
      expect(settings.apiKeys.length, equals(2));
      expect(settings.apiKeys[0].name, equals('Key 1'));
      expect(settings.apiKeys[1].name, equals('Key 2'));
    });

    test('SettingsState.copyWith updates apiKeys and supports legacy apiAccessToken/apiPermissions overrides', () {
      final initial = SettingsState();
      final updatedPermissions = const ApiPermissionsConfig(isReadOnly: true);
      final newLegacyToken = 'sol_sec_new_override_token_12345678901234567890123456789012345678901234';

      final modified = initial.copyWith(
        apiAccessToken: newLegacyToken,
        apiPermissions: updatedPermissions,
        requireLocalToken: true,
      );

      expect(modified.apiAccessToken, equals(newLegacyToken));
      expect(modified.apiPermissions, equals(updatedPermissions));
      expect(modified.apiKeys.first.token, equals(newLegacyToken));
      expect(modified.apiKeys.first.permissions, equals(updatedPermissions));
      expect(modified.requireLocalToken, isTrue);
    });
  });
}
