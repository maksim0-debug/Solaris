import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:solaris/models/post_update_result.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/services/post_update_service.dart';

void main() {
  late Directory tempTestDir;
  late String testLogPath;
  late String testAppDir;

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('post_update_test_');
    testLogPath = p.join(tempTestDir.path, 'Solaris', 'update.log');
    testAppDir = p.join(tempTestDir.path, 'app');

    await Directory(p.dirname(testLogPath)).create(recursive: true);
    await Directory(testAppDir).create(recursive: true);
  });

  tearDown(() async {
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  group('PostUpdateService tests', () {
    test(
      'readAndUpdateLog parses SUCCESS log and rotates file to update.last.log',
      () async {
        final logFile = File(testLogPath);
        final jsonLog = {
          'status': 'SUCCESS',
          'oldVersion': '1.0.17',
          'newVersion': '1.0.18',
          'timestamp': DateTime.now().toIso8601String(),
        };
        await logFile.writeAsString(jsonEncode(jsonLog));

        final service = PostUpdateService(
          overrideLogPath: testLogPath,
          overrideAppDir: testAppDir,
        );

        final result = await service.readAndUpdateLog();

        expect(result.status, equals(PostUpdateStatus.success));
        expect(result.oldVersion, equals('1.0.17'));
        expect(result.newVersion, equals('1.0.18'));

        // Verify update.log is renamed to update.last.log
        expect(await logFile.exists(), isFalse);
        final rotatedFile = File(
          p.join(p.dirname(testLogPath), 'update.last.log'),
        );
        expect(await rotatedFile.exists(), isTrue);
      },
    );

    test('readAndUpdateLog parses ROLLBACK log with reason', () async {
      final logFile = File(testLogPath);
      final jsonLog = {
        'status': 'ROLLBACK',
        'oldVersion': '1.0.17',
        'newVersion': '1.0.18',
        'reason': 'solaris.exe verification failed after extraction',
        'timestamp': DateTime.now().toIso8601String(),
      };
      await logFile.writeAsString(jsonEncode(jsonLog));

      final service = PostUpdateService(
        overrideLogPath: testLogPath,
        overrideAppDir: testAppDir,
      );

      final result = await service.readAndUpdateLog();

      expect(result.status, equals(PostUpdateStatus.rollback));
      expect(
        result.reason,
        equals('solaris.exe verification failed after extraction'),
      );
    });

    test(
      'readAndUpdateLog handles corrupted/invalid log file gracefully',
      () async {
        final logFile = File(testLogPath);
        await logFile.writeAsString('INVALID_JSON_CONTENT{{{');

        final service = PostUpdateService(
          overrideLogPath: testLogPath,
          overrideAppDir: testAppDir,
        );

        final result = await service.readAndUpdateLog();

        expect(result.status, equals(PostUpdateStatus.none));
        expect(await logFile.exists(), isFalse);
      },
    );

    test(
      'cleanupBackupFolderIfNeeded deletes backup folder on SUCCESS',
      () async {
        final backupDir = Directory(p.join(testAppDir, 'backup'));
        await backupDir.create(recursive: true);
        await File(
          p.join(backupDir.path, 'old_app.dll'),
        ).writeAsString('dummy');

        final service = PostUpdateService(
          overrideLogPath: testLogPath,
          overrideAppDir: testAppDir,
        );

        const successResult = PostUpdateResult(
          status: PostUpdateStatus.success,
        );
        await service.cleanupBackupFolderIfNeeded(successResult);

        expect(await backupDir.exists(), isFalse);
      },
    );

    test(
      'cleanupBackupFolderIfNeeded retains backup folder on ROLLBACK',
      () async {
        final backupDir = Directory(p.join(testAppDir, 'backup'));
        await backupDir.create(recursive: true);
        await File(
          p.join(backupDir.path, 'old_app.dll'),
        ).writeAsString('dummy');

        final service = PostUpdateService(
          overrideLogPath: testLogPath,
          overrideAppDir: testAppDir,
        );

        const rollbackResult = PostUpdateResult(
          status: PostUpdateStatus.rollback,
          reason: 'Error unpacking ZIP',
        );
        await service.cleanupBackupFolderIfNeeded(rollbackResult);

        expect(await backupDir.exists(), isTrue);
      },
    );

    test(
      'processPostUpdate completes without errors when no log exists',
      () async {
        final service = PostUpdateService(
          overrideLogPath: testLogPath,
          overrideAppDir: testAppDir,
        );

        final result = await service.processPostUpdate(
          startupMode: StartupMode.minimized,
        );

        expect(result.status, equals(PostUpdateStatus.none));
      },
    );
  });
}
