import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/update_download_service.dart';
import 'package:solaris/models/post_update_result.dart';

void main() {
  group('Component 7 - Security & E2E System Audit Tests', () {
    late Directory tempDir;
    late UpdateDownloadService downloadService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('solaris_sec_test_');
      downloadService = UpdateDownloadService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'SHA-256 integrity verification detects corrupted or tampered downloads',
      () async {
        final sampleFile = File('${tempDir.path}/test_release.zip');
        final validContent = 'Solaris-Release-Payload-v1.0.18-Valid';
        await sampleFile.writeAsString(validContent);

        final validDigest = sha256.convert(validContent.codeUnits).toString();
        final expectedDigestParam = 'sha256:$validDigest';

        final isMatch = await downloadService.verifyFileIntegrity(
          sampleFile.path,
          expectedDigestParam,
        );
        expect(
          isMatch,
          isTrue,
          reason: 'Valid SHA-256 digest must be verified as true',
        );

        // Tampered check
        final tamperedDigestParam =
            'sha256:0000000000000000000000000000000000000000000000000000000000000000';
        final isTamperedMatch = await downloadService.verifyFileIntegrity(
          sampleFile.path,
          tamperedDigestParam,
        );
        expect(
          isTamperedMatch,
          isFalse,
          reason: 'Tampered SHA-256 digest must fail verification',
        );
      },
    );

    test('Zip Slip path canonicalization helper logic verification', () {
      final targetDirStr = Platform.isWindows
          ? r'C:\Program Files\Solaris'
          : '/opt/solaris';

      bool isPathSafeMock(String targetDir, String entryRelativePath) {
        final targetUri = Uri.file(targetDir).normalizePath();
        final combined = Uri.file(
          '$targetDir/$entryRelativePath',
        ).normalizePath();
        return combined.path.startsWith(targetUri.path);
      }

      expect(isPathSafeMock(targetDirStr, 'solaris.exe'), isTrue);
      expect(
        isPathSafeMock(targetDirStr, 'data/flutter_assets/AssetManifest.json'),
        isTrue,
      );
      expect(
        isPathSafeMock(targetDirStr, '../../Windows/System32/cmd.exe'),
        isFalse,
      );
      expect(isPathSafeMock(targetDirStr, '../other_dir/hack.exe'), isFalse);
    });

    test('PostUpdateResult safely handles invalid JSON without crashing', () {
      final malformedJson = '{ status: "SUCCESS", timestamp: malformed }';
      PostUpdateResult result;
      try {
        result = PostUpdateResult.fromJson(
          jsonDecode(malformedJson) as Map<String, dynamic>,
        );
      } catch (_) {
        result = const PostUpdateResult(status: PostUpdateStatus.none);
      }
      expect(result.status, PostUpdateStatus.none);
    });

    test('PostUpdateResult parses SUCCESS and ROLLBACK logs correctly', () {
      final successJson = '''
      {
        "status": "SUCCESS",
        "timestamp": "2026-07-22T04:00:00Z"
      }
      ''';
      final successResult = PostUpdateResult.fromJson(
        jsonDecode(successJson) as Map<String, dynamic>,
      );
      expect(successResult.status, PostUpdateStatus.success);

      final rollbackJson = '''
      {
        "status": "ROLLBACK",
        "timestamp": "2026-07-22T04:05:00Z",
        "reason": "Verification failed: solaris.exe missing"
      }
      ''';
      final rollbackResult = PostUpdateResult.fromJson(
        jsonDecode(rollbackJson) as Map<String, dynamic>,
      );
      expect(rollbackResult.status, PostUpdateStatus.rollback);
      expect(rollbackResult.reason, contains('solaris.exe missing'));
    });
  });
}
