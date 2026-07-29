import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:win32/win32.dart';

import '../env/env.dart';
import '../models/update_status.dart';
import '../providers.dart';
import '../services/app_shutdown_service.dart';
import '../services/github_release_service.dart';
import '../services/update_download_service.dart';
import 'temperature_provider.dart';

/// Provider for [GitHubReleaseService].
final githubReleaseServiceProvider = Provider<GitHubReleaseService>((ref) {
  return GitHubReleaseService();
});

/// Provider for [UpdateDownloadService].
final updateDownloadServiceProvider = Provider<UpdateDownloadService>((ref) {
  return UpdateDownloadService();
});

/// Constant for Win32 ShellExecuteEx fMask parameter (SEE_MASK_NOCLOSEPROCESS)
const int _seeMaskNocloseprocess = 0x00000040;

/// Riverpod State Notifier managing the full application update lifecycle.
class UpdateNotifier extends Notifier<UpdateStatus> {
  static const String _lastCheckPrefKey = 'last_update_check_timestamp';

  @override
  UpdateStatus build() {
    return const UpdateStatus(phase: UpdatePhase.idle);
  }

  /// Sanitizes Windows file paths by normalizing slashes and stripping trailing backslashes.
  String sanitizePath(String path) {
    var normalized = path.replaceAll('/', '\\');
    while (normalized.endsWith('\\') && normalized.length > 3) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Checks for application updates from GitHub Releases.
  ///
  /// Set [isManual] to true for user-initiated checks (bypasses 1-hour throttling).
  /// [currentVersionOverride] can be supplied in unit tests or specific environments.
  Future<void> checkForUpdate({
    bool isManual = false,
    String? currentVersionOverride,
  }) async {
    if (!isManual) {
      try {
        final settingsMap = await ref.read(settingsProvider.future);
        final isAutoUpdateEnabled =
            settingsMap['all']?.isAutoUpdateEnabled ?? Env.isOfficialRelease;
        if (!isAutoUpdateEnabled) {
          developer.log(
            'Skipping automatic update check because auto-update is disabled in settings.',
            name: 'UpdateNotifier',
          );
          return;
        }
      } catch (e) {
        developer.log(
          'Failed to read auto-update setting: $e',
          name: 'UpdateNotifier',
        );
        return;
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final lastCheckEpoch = prefs.getInt(_lastCheckPrefKey) ?? 0;
        final nowEpoch = DateTime.now().millisecondsSinceEpoch;
        if (nowEpoch - lastCheckEpoch <
            const Duration(hours: 1).inMilliseconds) {
          developer.log(
            'Skipping automatic update check due to 1-hour throttling.',
            name: 'UpdateNotifier',
          );
          return;
        }
      } catch (e) {
        developer.log(
          'Failed to read SharedPreferences: $e',
          name: 'UpdateNotifier',
        );
      }
    }

    state = state.copyWith(
      phase: UpdatePhase.checking,
      nullifyErrorMessage: true,
      isUpToDateNotice: false,
    );

    try {
      String currentVersion;
      if (currentVersionOverride != null) {
        currentVersion = currentVersionOverride;
      } else {
        try {
          currentVersion = await ref.read(appVersionProvider.future);
        } catch (e) {
          developer.log(
            'Could not read package version from provider: $e',
            name: 'UpdateNotifier',
          );
          currentVersion = fallbackAppVersion;
        }
      }

      final githubService = ref.read(githubReleaseServiceProvider);
      final downloadService = ref.read(updateDownloadServiceProvider);

      final updateInfo = await githubService.checkForUpdate(currentVersion);

      // Store check timestamp
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _lastCheckPrefKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      } catch (_) {}

      if (updateInfo != null) {
        final cachedPath = await downloadService.getCachedUpdate(
          updateInfo.version,
          releaseService: githubService,
          expectedDigest: updateInfo.assetDigest,
        );
        if (cachedPath != null) {
          state = state.copyWith(
            phase: UpdatePhase.ready,
            updateInfo: updateInfo,
            downloadedFilePath: cachedPath,
            downloadProgress: 1.0,
            isUpToDateNotice: false,
          );
        } else {
          state = state.copyWith(
            phase: UpdatePhase.available,
            updateInfo: updateInfo,
            isUpToDateNotice: false,
          );
        }
      } else {
        state = state.copyWith(
          phase: UpdatePhase.idle,
          isUpToDateNotice: isManual,
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error during update check: $e',
        name: 'UpdateNotifier',
        error: e,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        phase: UpdatePhase.error,
        errorMessage: 'Error checking for updates: $e',
        isUpToDateNotice: false,
      );
    }
  }

  /// Resets the [isUpToDateNotice] flag back to false.
  void resetUpToDateNotice() {
    if (state.isUpToDateNotice) {
      state = state.copyWith(isUpToDateNotice: false);
    }
  }

  /// Downloads the update archive and performs SHA-256 integrity verification.
  Future<void> startDownload() async {
    final info = state.updateInfo;
    if (info == null) return;

    final downloadService = ref.read(updateDownloadServiceProvider);

    // Minimum required disk space: 100 MB
    const minBytes = 100 * 1024 * 1024;
    final tempDir = downloadService.updatesDirectory.path;
    final appExecutable = Platform.resolvedExecutable;
    final appDir = File(appExecutable).parent.path;

    if (!downloadService.hasEnoughDiskSpace(tempDir, minBytes) ||
        !downloadService.hasEnoughDiskSpace(appDir, minBytes)) {
      state = state.copyWith(
        phase: UpdatePhase.error,
        errorMessage:
            'Insufficient free disk space (minimum 100 MB required for temporary directory and target drive)',
      );
      return;
    }

    state = state.copyWith(
      phase: UpdatePhase.downloading,
      downloadProgress: 0.0,
      nullifyErrorMessage: true,
    );

    try {
      final tmpFilePath = await downloadService.downloadUpdate(
        info.downloadUrl,
        info.version,
        expectedSize: info.assetSize,
        onProgress: (progress) {
          state = state.copyWith(downloadProgress: progress);
        },
      );

      // Phase: verifying
      state = state.copyWith(phase: UpdatePhase.verifying);

      if (info.assetDigest == null || info.assetDigest!.isEmpty) {
        final tmpFile = File(tmpFilePath);
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
        developer.log(
          'Integrity verification failed: SHA-256 digest is missing from release metadata',
          name: 'UpdateNotifier',
        );
        state = state.copyWith(
          phase: UpdatePhase.error,
          errorMessage:
              'Integrity verification failed: SHA-256 digest is missing from release metadata',
        );
        return;
      }

      final githubService = ref.read(githubReleaseServiceProvider);

      final fileHash = await downloadService.computeFileSha256(tmpFilePath);
      if (fileHash == null) {
        final tmpFile = File(tmpFilePath);
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
        state = state.copyWith(
          phase: UpdatePhase.error,
          errorMessage:
              'Integrity verification failed: Could not calculate SHA-256 hash of downloaded update file',
        );
        return;
      }

      // Check SHA-256 digest against release metadata
      final isValidDigest = await downloadService.verifyFileIntegrity(
        tmpFilePath,
        info.assetDigest!,
      );
      if (!isValidDigest) {
        final tmpFile = File(tmpFilePath);
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
        state = state.copyWith(
          phase: UpdatePhase.error,
          errorMessage:
              'Integrity verification failed: downloaded file hash does not match expected release digest',
        );
        return;
      }

      // Verify SLSA provenance attestation against GitHub Attestations API
      final isAttested = await githubService.verifyArtifactAttestation(
        fileHash,
      );
      if (!isAttested) {
        final tmpFile = File(tmpFilePath);
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
        developer.log(
          'Integrity verification failed: SLSA attestation check failed for hash $fileHash',
          name: 'UpdateNotifier',
        );
        state = state.copyWith(
          phase: UpdatePhase.error,
          errorMessage:
              'Security verification failed: Update package lacks a valid GitHub Actions SLSA attestation. The file may have been tampered with.',
        );
        return;
      }

      final finalZipPath = await downloadService.finalizeDownload(
        tmpFilePath,
        info.version,
      );
      await downloadService.cleanupOldDownloads(keepVersion: info.version);

      state = state.copyWith(
        phase: UpdatePhase.ready,
        downloadedFilePath: finalZipPath,
        downloadProgress: 1.0,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error during update download: $e',
        name: 'UpdateNotifier',
        error: e,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        phase: UpdatePhase.error,
        errorMessage: e is InsufficientDiskSpaceException
            ? e.message
            : 'Error downloading update: $e',
      );
    }
  }

  /// Triggers the installation process: copies `solaris_updater.exe` to a temporary folder
  /// and launches it with arguments, handing over execution before shutting down Solaris.
  Future<void> installAndRestart() async {
    if (state.phase != UpdatePhase.ready || state.downloadedFilePath == null) {
      return;
    }

    state = state.copyWith(phase: UpdatePhase.installing);

    try {
      final downloadedZipPath = sanitizePath(state.downloadedFilePath!);
      final appExecutable = Platform.resolvedExecutable;
      final appDir = sanitizePath(File(appExecutable).parent.path);
      final updaterSource = '$appDir\\solaris_updater.exe';

      final tempDir = Directory(
        '${Directory.systemTemp.path}\\solaris_updater_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      final updaterTempPath = '${tempDir.path}\\solaris_updater.exe';

      // Ensure target backup folder sits alongside the app directory on the same drive
      final parentDir = File(appDir).parent.path;
      final backupDir = sanitizePath('$parentDir\\solaris_backup');

      // Copy solaris_updater.exe to temp directory so it can overwrite files in appDir without locking
      final sourceFile = File(updaterSource);
      if (await sourceFile.exists()) {
        await sourceFile.copy(updaterTempPath);
      } else {
        throw Exception(
          'Helper executable solaris_updater.exe not found at $updaterSource',
        );
      }

      // Check write permissions in appDir (Program Files check)
      bool hasWriteAccess = true;
      try {
        final testFile = File(
          '$appDir\\.write_test_${DateTime.now().millisecondsSinceEpoch}',
        );
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (_) {
        hasWriteAccess = false;
      }

      final currentPid = pid;
      final argsList = [
        '--pid',
        '$currentPid',
        '--zip',
        downloadedZipPath,
        '--target',
        appDir,
        '--exe',
        'solaris.exe',
        '--backup',
        backupDir,
      ];

      // Lock temperature control and reset monitor color temperature to neutral (6500K) prior to launching updater
      ref.read(temperatureServiceProvider).lockTemperatureControl();
      await ref
          .read(isColorTemperatureEnabledProvider.notifier)
          .resetToNeutralNow();

      bool launched = false;
      if (hasWriteAccess) {
        await Process.start(
          updaterTempPath,
          argsList,
          mode: ProcessStartMode.detached,
        );
        launched = true;
      } else {
        final formattedArgs = argsList.map((arg) => '"$arg"').join(' ');
        launched = _launchElevated(updaterTempPath, formattedArgs);
      }

      if (!launched) {
        await _restoreTemperatureAfterFailure();
        state = state.copyWith(
          phase: UpdatePhase.error,
          errorMessage:
              'User cancelled admin elevation (UAC) or update execution failed.',
        );
        return;
      }

      // Perform full graceful shutdown of all sub-systems before handing control over to solaris_updater.exe
      final shutdownService = AppShutdownService(ref.container);
      await shutdownService.performShutdown();
    } catch (e, stackTrace) {
      await _restoreTemperatureAfterFailure();
      developer.log(
        'Error initiating update installation: $e',
        name: 'UpdateNotifier',
        error: e,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        phase: UpdatePhase.error,
        errorMessage: 'Failed to launch update installation: $e',
      );
    }
  }

  Future<void> _restoreTemperatureAfterFailure() async {
    final tempService = ref.read(temperatureServiceProvider);
    tempService.unlockTemperatureControl();

    if (ref.read(isColorTemperatureEnabledProvider) &&
        !ref.read(autoTemperatureAdjustmentProvider)) {
      final targetTemp = ref.read(currentTemperatureProvider);
      try {
        final monitors = await ref.read(monitorListProvider.future);
        final monitorService = ref.read(monitorServiceProvider);
        await tempService.setTemperatureInstant(
          selection: 'all',
          targetValue: targetTemp.toDouble(),
          monitors: monitors,
          monitorService: monitorService,
          updateTemperatureCallback: (id, val) {},
        );
      } catch (_) {}
    }
  }

  /// Helper to launch executable with UAC admin elevation using Win32 ShellExecuteEx.
  /// Returns `true` if process was launched successfully, `false` otherwise (e.g. UAC cancelled).
  bool _launchElevated(String executable, String arguments) {
    if (!Platform.isWindows) return false;
    try {
      return using((arena) {
        final pExec = executable.toNativeUtf16(allocator: arena);
        final pArgs = arguments.toNativeUtf16(allocator: arena);
        final pVerb = 'runas'.toNativeUtf16(allocator: arena);

        final sei = arena<SHELLEXECUTEINFO>()
          ..ref.cbSize = sizeOf<SHELLEXECUTEINFO>()
          ..ref.fMask = _seeMaskNocloseprocess
          ..ref.lpVerb = pVerb
          ..ref.lpFile = pExec
          ..ref.lpParameters = pArgs
          ..ref.nShow = SW_SHOW;

        return ShellExecuteEx(sei) != 0;
      });
    } catch (e) {
      developer.log(
        'Error launching elevated process: $e',
        name: 'UpdateNotifier',
      );
      return false;
    }
  }

  /// Dismisses current update notice and resets to idle phase.
  void dismissUpdate() {
    state = state.copyWith(phase: UpdatePhase.idle);
  }

  /// Resets error state back to idle phase.
  void resetError() {
    unawaited(_restoreTemperatureAfterFailure());
    state = state.copyWith(phase: UpdatePhase.idle, nullifyErrorMessage: true);
  }
}

/// Riverpod provider definition for [UpdateNotifier].
final updateProvider = NotifierProvider<UpdateNotifier, UpdateStatus>(
  UpdateNotifier.new,
);
