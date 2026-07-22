import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:solaris/models/post_update_result.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/services/autorun_service.dart';

/// PostUpdateService handles validation, retention logging, artifact cleanup,
/// and autorun registry synchronization after application updates.
class PostUpdateService {
  final String? overrideLogPath;
  final String? overrideAppDir;

  PostUpdateService({
    this.overrideLogPath,
    this.overrideAppDir,
  });

  /// Resolves the default updater log file path (%LOCALAPPDATA%/Solaris/update.log).
  String get updateLogPath {
    if (overrideLogPath != null) return overrideLogPath!;
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      return p.join(localAppData, 'Solaris', 'update.log');
    }
    return p.join(Directory.systemTemp.path, 'Solaris', 'update.log');
  }

  /// Resolves the application directory.
  String get appDirectory {
    if (overrideAppDir != null) return overrideAppDir!;
    return p.dirname(Platform.resolvedExecutable);
  }

  /// Performs full post-update validation and cleanup workflow upon application launch.
  Future<PostUpdateResult> processPostUpdate({
    required StartupMode startupMode,
  }) async {
    developer.log('Executing post-update processing...', name: 'PostUpdateService');

    // Step 1: Read and parse update.log
    final result = await readAndUpdateLog();

    // Step 2: Clean up backup directory if update was successful
    await cleanupBackupFolderIfNeeded(result);

    // Step 3: Refresh autorun registry entry if enabled
    await updateAutorunRegistryIfNeeded(startupMode);

    // Step 4: Perform delayed artifact cleanup & background GC for old temp folders (> 24h)
    // Run asynchronously in background without blocking application startup thread
    unawaited(cleanupTempFilesAndGC());

    return result;
  }

  /// Reads and parses `update.log`, then renames it to `update.last.log` for retention debugging.
  Future<PostUpdateResult> readAndUpdateLog() async {
    final logFile = File(updateLogPath);
    if (!await logFile.exists()) {
      return const PostUpdateResult(status: PostUpdateStatus.none);
    }

    PostUpdateResult result;
    try {
      final content = await logFile.readAsString();
      if (content.trim().isEmpty) {
        result = const PostUpdateResult(status: PostUpdateStatus.none);
      } else {
        final jsonMap = jsonDecode(content) as Map<String, dynamic>;
        result = PostUpdateResult.fromJson(jsonMap);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to read or parse update.log, deleting corrupted log file: $e',
        name: 'PostUpdateService',
        error: e,
        stackTrace: stackTrace,
      );
      result = const PostUpdateResult(status: PostUpdateStatus.none);
    }

    // Retention: Rename update.log -> update.last.log
    try {
      final lastLogPath = p.join(p.dirname(updateLogPath), 'update.last.log');
      final lastLogFile = File(lastLogPath);
      if (await lastLogFile.exists()) {
        await lastLogFile.delete();
      }
      await logFile.rename(lastLogPath);
      developer.log(
        'Renamed update.log to update.last.log for retention',
        name: 'PostUpdateService',
      );
    } catch (e) {
      developer.log(
        'Could not rotate update.log to update.last.log: $e',
        name: 'PostUpdateService',
      );
      try {
        if (await logFile.exists()) {
          await logFile.delete();
        }
      } catch (_) {}
    }

    return result;
  }

  /// Removes the `backup` directory if the update was successful.
  /// Retains the backup directory intact if [result.status] is [PostUpdateStatus.rollback] or [PostUpdateStatus.error].
  Future<void> cleanupBackupFolderIfNeeded(PostUpdateResult result) async {
    if (result.status != PostUpdateStatus.success) {
      developer.log(
        'Skipping backup folder deletion because update status is ${result.status}',
        name: 'PostUpdateService',
      );
      return;
    }

    final backupPathCandidate1 = p.join(appDirectory, 'backup');
    final backupPathCandidate2 = p.join(p.dirname(appDirectory), 'solaris_backup');

    for (final backupPath in [backupPathCandidate1, backupPathCandidate2]) {
      try {
        final backupDir = Directory(backupPath);
        if (await backupDir.exists()) {
          await backupDir.delete(recursive: true);
          developer.log(
            'Successfully deleted post-update backup directory: $backupPath',
            name: 'PostUpdateService',
          );
        }
      } catch (e) {
        developer.log(
          'Failed to clean up backup directory $backupPath: $e',
          name: 'PostUpdateService',
        );
      }
    }
  }

  /// Refreshes the Windows Registry autorun key if autorun is registered anywhere.
  Future<void> updateAutorunRegistryIfNeeded(StartupMode startupMode) async {
    if (!Platform.isWindows) return;

    try {
      final isRegisteredAnywhere = await AutorunService.isRegisteredAnywhere();
      if (isRegisteredAnywhere) {
        final success = await AutorunService.setEnabled(true, startupMode);
        if (success) {
          developer.log(
            'Updated Windows autorun registry path to ${Platform.resolvedExecutable}',
            name: 'PostUpdateService',
          );
        }
      }
    } catch (e) {
      developer.log(
        'Failed to update autorun registry key: $e',
        name: 'PostUpdateService',
      );
    }
  }

  /// Cleans up temporary download artifacts and performs background garbage collection
  /// on updater temporary folders older than 24 hours.
  Future<void> cleanupTempFilesAndGC() async {
    // 3-second delay to give Windows OS time to release file handles for updater.exe
    await Future<void>.delayed(const Duration(seconds: 3));

    final tempDir = Directory.systemTemp;
    if (!await tempDir.exists()) return;

    final now = DateTime.now();

    try {
      final entities = tempDir.listSync(recursive: false);
      for (final entity in entities) {
        final name = p.basename(entity.path);
        final isUpdaterFolder = name.startsWith('solaris_updater_');
        final isUpdatesFolder = name == 'solaris_updates' || name.startsWith('solaris_updates_');

        if (!isUpdaterFolder && !isUpdatesFolder) continue;

        try {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          // Immediate cleanup for empty/temporary folders or older than 24 hours
          if (age.inHours >= 24 || isUpdaterFolder) {
            if (entity is Directory) {
              await entity.delete(recursive: true);
            } else if (entity is File) {
              await entity.delete();
            }
            developer.log(
              'Cleaned up temp update artifact: ${entity.path}',
              name: 'PostUpdateService',
            );
          }
        } catch (e) {
          // Graceful degradation for locked handles
          developer.log(
            'Temp file cleanup skipped for ${entity.path}: $e',
            name: 'PostUpdateService',
          );
        }
      }
    } catch (e) {
      developer.log(
        'Error during temp files garbage collection: $e',
        name: 'PostUpdateService',
      );
    }
  }
}

/// Helper function to execute Future without waiting.
void unawaited(Future<void> future) {}
