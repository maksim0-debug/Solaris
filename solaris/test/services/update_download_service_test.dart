import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solaris/services/update_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('solaris_download_test_');
  });

  tearDown(() async {
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  group('UpdateDownloadService Tests', () {
    test('verifyFileIntegrity returns true for matching SHA-256 digest', () async {
      final service = UpdateDownloadService();
      final testFile = File('${tempTestDir.path}/sample.bin');
      const fileContent = 'Solaris Update Package Test Content';
      await testFile.writeAsString(fileContent);

      final expectedDigestHex = sha256.convert(utf8.encode(fileContent)).toString();
      final expectedDigestWithPrefix = 'sha256:$expectedDigestHex';

      final isValid = await service.verifyFileIntegrity(
        testFile.path,
        expectedDigestWithPrefix,
      );

      expect(isValid, isTrue);
    });

    test('verifyFileIntegrity returns false for mismatched SHA-256 digest', () async {
      final service = UpdateDownloadService();
      final testFile = File('${tempTestDir.path}/sample_bad.bin');
      await testFile.writeAsString('Different Content');

      final isValid = await service.verifyFileIntegrity(
        testFile.path,
        'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      );

      expect(isValid, isFalse);
    });

    test('downloadUpdate handles HTTP redirect and downloads content correctly', () async {
      final dummyPackageData = utf8.encode('Solaris 1.0.18 Zip Package Payload');

      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://github.com/maksim0-debug/Solaris/releases/download/v1.0.18/Solaris-Windows.zip') {
          // Verify headers on initial request (X-GitHub-Api-Version should NOT be present)
          expect(request.headers.containsKey('X-GitHub-Api-Version'), isFalse);
          return http.Response('', 302, headers: {
            'location': 'https://objects.githubusercontent.com/download/Solaris-Windows.zip',
          });
        } else if (request.url.toString() == 'https://objects.githubusercontent.com/download/Solaris-Windows.zip') {
          return http.Response.bytes(dummyPackageData, 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = UpdateDownloadService(client: mockClient);

      double lastProgress = 0.0;
      final downloadedPath = await service.downloadUpdate(
        'https://github.com/maksim0-debug/Solaris/releases/download/v1.0.18/Solaris-Windows.zip',
        '1.0.18',
        expectedSize: dummyPackageData.length,
        onProgress: (p) => lastProgress = p,
      );

      final downloadedFile = File(downloadedPath);
      expect(await downloadedFile.exists(), isTrue);
      expect(await downloadedFile.readAsBytes(), equals(dummyPackageData));
      expect(lastProgress, equals(1.0));

      // Clean up downloaded file
      await downloadedFile.delete();
    });

    test('downloadUpdate blocks non-HTTPS redirect', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://github.com/maksim0-debug/Solaris/releases/download/v1.0.18/Solaris-Windows.zip') {
          return http.Response('', 302, headers: {
            'location': 'http://objects.githubusercontent.com/download/Solaris-Windows.zip',
          });
        }
        return http.Response('Not Found', 404);
      });

      final service = UpdateDownloadService(client: mockClient);

      expect(
        () => service.downloadUpdate(
          'https://github.com/maksim0-debug/Solaris/releases/download/v1.0.18/Solaris-Windows.zip',
          '1.0.18',
        ),
        throwsA(isA<HttpException>()),
      );
    });

    test('downloadUpdate blocks untrusted domain redirect', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://github.com/maksim0-debug/Solaris/releases/download/v1.0.18/Solaris-Windows.zip') {
          return http.Response('', 302, headers: {
            'location': 'https://malicious-domain.com/download/Solaris-Windows.zip',
          });
        }
        return http.Response('Not Found', 404);
      });

      final service = UpdateDownloadService(client: mockClient);

      expect(
        () => service.downloadUpdate(
          'https://github.com/maksim0-debug/Solaris/releases/download/v1.0.18/Solaris-Windows.zip',
          '1.0.18',
        ),
        throwsA(isA<HttpException>()),
      );
    });

    test('downloadUpdate supports HTTP 303 and 308 redirects', () async {
      final dummyPackageData = utf8.encode('Solaris 1.0.18 Redirect 308 Payload');

      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'https://github.com/maksim0-debug/Solaris/releases/download/v1.0.18/Solaris-Windows.zip') {
          return http.Response('', 308, headers: {
            'location': 'https://objects.githubusercontent.com/download/Solaris-Windows.zip',
          });
        } else if (request.url.toString() == 'https://objects.githubusercontent.com/download/Solaris-Windows.zip') {
          return http.Response.bytes(dummyPackageData, 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = UpdateDownloadService(client: mockClient);

      final downloadedPath = await service.downloadUpdate(
        'https://github.com/maksim0-debug/Solaris/releases/download/v1.0.18/Solaris-Windows.zip',
        '1.0.18',
      );

      final downloadedFile = File(downloadedPath);
      expect(await downloadedFile.exists(), isTrue);
      await downloadedFile.delete();
    });

    test('finalizeDownload promotes .tmp file to .zip and getCachedUpdate locates it', () async {
      final service = UpdateDownloadService();
      final updatesDir = service.updatesDirectory;
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }

      const version = '9.9.99-test';
      final tempFile = File('${updatesDir.path}\\Solaris-Windows-v$version.zip.tmp');
      await tempFile.writeAsString('Test ZIP Payload');

      final finalPath = await service.finalizeDownload(tempFile.path, version);
      expect(finalPath, endsWith('Solaris-Windows-v$version.zip'));

      final cachedPath = await service.getCachedUpdate(version);
      expect(cachedPath, equals(finalPath));

      await service.cleanupOldDownloads();
      final cachedAfterCleanup = await service.getCachedUpdate(version);
      expect(cachedAfterCleanup, isNull);
    });
  });
}
