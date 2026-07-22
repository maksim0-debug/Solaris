import 'package:meta/meta.dart';
import 'update_info.dart';

/// Enum representing the phases of the application update lifecycle.
enum UpdatePhase {
  /// No update process active (idle state).
  idle,

  /// Checking GitHub Releases API for new version.
  checking,

  /// New update version is available for download.
  available,

  /// Update ZIP package is downloading.
  downloading,

  /// Verifying SHA-256 integrity of downloaded package.
  verifying,

  /// Downloaded and verified, ready for installation.
  ready,

  /// Control handed off to native `updater.exe` for installation.
  installing,

  /// Error occurred during check, download, or verification.
  error,
}

/// Immutable state class representing current status of the software update lifecycle.
@immutable
class UpdateStatus {
  final UpdatePhase phase;
  final UpdateInfo? updateInfo;
  final double downloadProgress;
  final String? errorMessage;
  final String? downloadedFilePath;

  const UpdateStatus({
    this.phase = UpdatePhase.idle,
    this.updateInfo,
    this.downloadProgress = 0.0,
    this.errorMessage,
    this.downloadedFilePath,
  });

  UpdateStatus copyWith({
    UpdatePhase? phase,
    UpdateInfo? updateInfo,
    bool nullifyUpdateInfo = false,
    double? downloadProgress,
    String? errorMessage,
    bool nullifyErrorMessage = false,
    String? downloadedFilePath,
    bool nullifyDownloadedFilePath = false,
  }) {
    return UpdateStatus(
      phase: phase ?? this.phase,
      updateInfo: nullifyUpdateInfo ? null : (updateInfo ?? this.updateInfo),
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: nullifyErrorMessage ? null : (errorMessage ?? this.errorMessage),
      downloadedFilePath: nullifyDownloadedFilePath
          ? null
          : (downloadedFilePath ?? this.downloadedFilePath),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateStatus &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          updateInfo == other.updateInfo &&
          downloadProgress == other.downloadProgress &&
          errorMessage == other.errorMessage &&
          downloadedFilePath == other.downloadedFilePath;

  @override
  int get hashCode =>
      phase.hashCode ^
      updateInfo.hashCode ^
      downloadProgress.hashCode ^
      errorMessage.hashCode ^
      downloadedFilePath.hashCode;

  @override
  String toString() {
    return 'UpdateStatus(phase: $phase, updateInfo: ${updateInfo?.version}, progress: $downloadProgress, error: $errorMessage)';
  }
}
