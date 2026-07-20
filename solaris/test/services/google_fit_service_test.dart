import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/google_fit_service.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:solaris/utils/key_obfuscator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Создаем локальную временную директорию внутри проекта для тестирования
  final tempDir = Directory('test_support_dir');

  setUpAll(() async {
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    // Мокаем канал path_provider
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationSupportDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    // Очищаем файлы и состояние синглтона перед каждым тестом
    await GoogleFitService().signOut();
  });

  group('GoogleFitService Secure Token Storage Tests', () {
    final mockCredentials = {
      'accessToken': {
        'type': 'Bearer',
        'data': 'mock_access_token_123',
        'expiry': DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
      },
      'refreshToken': 'mock_refresh_token_456',
      'scopes': ['https://www.googleapis.com/auth/fitness.sleep.read'],
    };

    test('Backward compatibility - reads plaintext token, initializes, and migrates to encrypted format on disk', () async {
      // 1. Записываем обычный незашифрованный JSON на диск (эмуляция старых версий приложения)
      final plaintextJson = jsonEncode(mockCredentials);
      final file = File('${tempDir.path}/google_fit_token.json');
      await file.writeAsString(plaintextJson, flush: true);

      // 2. Инициализируем сервис — он должен прочитать токен и запустить миграцию
      final service = GoogleFitService();
      final initialized = await service.initialize();
      expect(initialized, isTrue);
      expect(service.isConnected, isTrue);

      // 3. Проверяем, что файл на диске был перезаписан в зашифрованном формате (миграция прошла успешно)
      final onDiskContent = await file.readAsString();
      expect(onDiskContent, isNot(equals(plaintextJson)));
      expect(
        onDiskContent.startsWith('dpapi:') || onDiskContent.startsWith('obf:'),
        isTrue,
      );
    });

    test('Encryption - saves encrypted token to disk and decrypts it during init', () async {
      final service = GoogleFitService();
      final storage = StorageService();

      // 1. Шифруем и сохраняем токен через StorageService (эмуляция сохранения в google_fit_service)
      final jsonStr = jsonEncode(mockCredentials);
      final encryptedStr = KeyObfuscator.encrypt(jsonStr);
      await storage.save('google_fit_token.json', encryptedStr);

      // Проверяем, что на диске сохранен именно зашифрованный текст с нужным префиксом
      final file = File('${tempDir.path}/google_fit_token.json');
      final onDiskContent = await file.readAsString();
      expect(onDiskContent, isNot(equals(jsonStr)));
      expect(
        onDiskContent.startsWith('dpapi:') || onDiskContent.startsWith('obf:'),
        isTrue,
      );

      // 2. Инициализируем сервис — он должен успешно расшифровать и загрузить токен
      final initialized = await service.initialize();
      expect(initialized, isTrue);
      expect(service.isConnected, isTrue);
    });

    test('Corrupted encrypted token - fails gracefully, isConnected is false and file is deleted', () async {
      // 1. Записываем поврежденные зашифрованные данные
      final file = File('${tempDir.path}/google_fit_token.json');
      await file.writeAsString('obf:invalid_base_64_data_!!!', flush: true);

      // 2. Инициализация должна вернуть false, а сервис остаться неподключенным
      final service = GoogleFitService();
      final initialized = await service.initialize();
      expect(initialized, isFalse);
      expect(service.isConnected, isFalse);

      // 3. Проверяем, что битый файл был автоматически удален с диска
      expect(await file.exists(), isFalse);
    });
  });
}
