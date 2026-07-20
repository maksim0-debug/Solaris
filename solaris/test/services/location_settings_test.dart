import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/location_settings.dart';
import 'package:solaris/utils/key_obfuscator.dart';

void main() {
  group('LocationSettings and DPAPI Encryption Tests', () {
    test('Serialization and deserialization of new fields', () {
      const settings = LocationSettings(
        useManual: true,
        manualLatitude: 40.7128,
        manualLongitude: -74.0060,
        lastCityName: 'New York',
        lastResolvedLatitude: 40.7120,
        lastResolvedLongitude: -74.0050,
      );

      final jsonMap = settings.toJson();
      expect(jsonMap['useManual'], true);
      expect(jsonMap['manualLatitude'], 40.7128);
      expect(jsonMap['manualLongitude'], -74.0060);
      expect(jsonMap['lastCityName'], 'New York');
      expect(jsonMap['lastResolvedLatitude'], 40.7120);
      expect(jsonMap['lastResolvedLongitude'], -74.0050);

      final deserialized = LocationSettings.fromJson(jsonMap);
      expect(deserialized.useManual, true);
      expect(deserialized.manualLatitude, 40.7128);
      expect(deserialized.manualLongitude, -74.0060);
      expect(deserialized.lastCityName, 'New York');
      expect(deserialized.lastResolvedLatitude, 40.7120);
      expect(deserialized.lastResolvedLongitude, -74.0050);
    });

    test('Encryption and decryption via KeyObfuscator', () {
      const settings = LocationSettings(
        useManual: true,
        manualLatitude: 50.4547,
        manualLongitude: 30.5238,
        lastCityName: 'Kyiv',
        lastResolvedLatitude: 50.4547,
        lastResolvedLongitude: 30.5238,
      );

      final jsonStr = jsonEncode(settings.toJson());
      final encrypted = KeyObfuscator.encrypt(jsonStr);
      
      // DPAPI prefix check
      expect(encrypted.startsWith('dpapi:') || encrypted.startsWith('obf:'), true);

      final decrypted = KeyObfuscator.decrypt(encrypted);
      expect(decrypted, jsonStr);

      final deserialized = LocationSettings.fromJson(
        jsonDecode(decrypted) as Map<String, dynamic>,
      );
      expect(deserialized, settings);
    });

    test('Seamless compatibility with unencrypted legacy settings', () {
      const legacyJson = '{"useManual":false,"manualLatitude":40.88230371608771,"manualLongitude":-111.62138879049142,"lastCityName":null}';
      
      // Decrypting unencrypted string should return it as-is
      final result = KeyObfuscator.decrypt(legacyJson);
      expect(result, legacyJson);

      final settings = LocationSettings.fromJson(
        jsonDecode(result) as Map<String, dynamic>,
      );
      expect(settings.useManual, false);
      expect(settings.manualLatitude, 40.88230371608771);
      expect(settings.manualLongitude, -111.62138879049142);
      expect(settings.lastCityName, null);
      expect(settings.lastResolvedLatitude, null);
      expect(settings.lastResolvedLongitude, null);
    });

    test('Coordinates are clamped to valid geographical bounds', () {
      final jsonMap = {
        'useManual': true,
        'manualLatitude': 440000.0,
        'manualLongitude': -250.0,
        'lastCityName': 'Test Clamping',
        'lastResolvedLatitude': -120.0,
        'lastResolvedLongitude': 190.0,
      };

      final settings = LocationSettings.fromJson(jsonMap);
      expect(settings.manualLatitude, 90.0);
      expect(settings.manualLongitude, -180.0);
      expect(settings.lastResolvedLatitude, -90.0);
      expect(settings.lastResolvedLongitude, 180.0);

      final copied = settings.copyWith(
        manualLatitude: 100.0,
        manualLongitude: -200.0,
        lastResolvedLatitude: -95.0,
        lastResolvedLongitude: 210.0,
      );
      expect(copied.manualLatitude, 90.0);
      expect(copied.manualLongitude, -180.0);
      expect(copied.lastResolvedLatitude, -90.0);
      expect(copied.lastResolvedLongitude, 180.0);
    });

    test('copyWith keeps existing values when arguments are null', () {
      const settings = LocationSettings(
        useManual: true,
        manualLatitude: 45.0,
        manualLongitude: 90.0,
        lastCityName: 'TestCity',
        lastResolvedLatitude: 50.0,
        lastResolvedLongitude: 100.0,
      );

      final copied = settings.copyWith();
      expect(copied, settings);

      final copiedWithNulls = settings.copyWith(
        useManual: null,
        manualLatitude: null,
        manualLongitude: null,
        lastCityName: null,
        lastResolvedLatitude: null,
        lastResolvedLongitude: null,
      );
      expect(copiedWithNulls.useManual, true);
      expect(copiedWithNulls.manualLatitude, 45.0);
      expect(copiedWithNulls.manualLongitude, 90.0);
      expect(copiedWithNulls.lastCityName, 'TestCity');
      expect(copiedWithNulls.lastResolvedLatitude, 50.0);
      expect(copiedWithNulls.lastResolvedLongitude, 100.0);

      final copiedWithNewValues = settings.copyWith(
        useManual: false,
        manualLatitude: 10.0,
        lastCityName: 'NewCity',
      );
      expect(copiedWithNewValues.useManual, false);
      expect(copiedWithNewValues.manualLatitude, 10.0);
      expect(copiedWithNewValues.manualLongitude, 90.0); // сохранено
      expect(copiedWithNewValues.lastCityName, 'NewCity');
      expect(copiedWithNewValues.lastResolvedLatitude, 50.0); // сохранено
    });
  });
}
