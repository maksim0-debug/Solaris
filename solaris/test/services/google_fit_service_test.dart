import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/google_fit_service.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:solaris/utils/key_obfuscator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Create local temporary directory inside project for testing
  final tempDir = Directory('test_support_dir');

  setUpAll(() async {
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    // Mock path_provider channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationSupportDirectory') {
              return tempDir.path;
            }
            return null;
          },
        );
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    // Clean up files and singleton state before each test
    await GoogleFitService().signOut();
  });

  group('GoogleFitService Secure Token Storage Tests', () {
    final mockCredentials = {
      'accessToken': {
        'type': 'Bearer',
        'data': 'mock_access_token_123',
        'expiry': DateTime.now()
            .add(const Duration(hours: 2))
            .toUtc()
            .toIso8601String(),
      },
      'refreshToken': 'mock_refresh_token_456',
      'scopes': ['https://www.googleapis.com/auth/fitness.sleep.read'],
    };

    test(
      'Backward compatibility - reads plaintext token, initializes, and migrates to encrypted format on disk',
      () async {
        // 1. Write unencrypted JSON to disk (emulating older app versions)
        final plaintextJson = jsonEncode(mockCredentials);
        final file = File('${tempDir.path}/google_fit_token.json');
        await file.writeAsString(plaintextJson, flush: true);

        // 2. Initialize service — it should read token and trigger migration
        final service = GoogleFitService();
        final initialized = await service.initialize();
        expect(initialized, isTrue);
        expect(service.isConnected, isTrue);

        // 3. Verify file on disk was overwritten in encrypted format (migration successful)
        final onDiskContent = await file.readAsString();
        expect(onDiskContent, isNot(equals(plaintextJson)));
        expect(
          onDiskContent.startsWith('dpapi:') ||
              onDiskContent.startsWith('obf:'),
          isTrue,
        );
      },
    );

    test(
      'Encryption - saves encrypted token to disk and decrypts it during init',
      () async {
        final service = GoogleFitService();
        final storage = StorageService();

        // 1. Encrypt and save token via StorageService (emulating save in google_fit_service)
        final jsonStr = jsonEncode(mockCredentials);
        final encryptedStr = KeyObfuscator.encrypt(jsonStr);
        await storage.save('google_fit_token.json', encryptedStr);

        // Verify that encrypted text with expected prefix is saved to disk
        final file = File('${tempDir.path}/google_fit_token.json');
        final onDiskContent = await file.readAsString();
        expect(onDiskContent, isNot(equals(jsonStr)));
        expect(
          onDiskContent.startsWith('dpapi:') ||
              onDiskContent.startsWith('obf:'),
          isTrue,
        );

        // 2. Initialize service — it should successfully decrypt and load token
        final initialized = await service.initialize();
        expect(initialized, isTrue);
        expect(service.isConnected, isTrue);
      },
    );

    test(
      'Corrupted encrypted token - fails gracefully, isConnected is false and file is deleted',
      () async {
        // 1. Write corrupted encrypted data
        final file = File('${tempDir.path}/google_fit_token.json');
        await file.writeAsString('obf:invalid_base_64_data_!!!', flush: true);

        // 2. Initialization should return false and service should remain disconnected
        final service = GoogleFitService();
        final initialized = await service.initialize();
        expect(initialized, isFalse);
        expect(service.isConnected, isFalse);

        // 3. Verify corrupted file was automatically removed from disk
        expect(await file.exists(), isFalse);
      },
    );
  });
}
