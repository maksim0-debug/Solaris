import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:http/http.dart' as http;
import 'package:win32/win32.dart';
import 'github_release_service.dart';

/// Exception thrown when there is insufficient disk space for downloading or installing an update.
class InsufficientDiskSpaceException implements Exception {
  final String message;
  InsufficientDiskSpaceException(this.message);

  @override
  String toString() => 'InsufficientDiskSpaceException: $message';
}

/// Service responsible for downloading software update archives, verifying their integrity,
/// checking available disk space, and managing cached update files.
class UpdateDownloadService {
  final http.Client _client;

  UpdateDownloadService({http.Client? client})
    : _client = client ?? http.Client();

  /// Directory used for storing downloaded update archives (%TEMP%/solaris_updates).
  Directory get updatesDirectory {
    final tempPath = Directory.systemTemp.path;
    return Directory('$tempPath\\solaris_updates');
  }

  /// Checks if there is enough free disk space at [path] for [requiredBytes].
  ///
  /// Minimum required space for update downloads is typically 100 MB.
  bool hasEnoughDiskSpace(String path, int requiredBytes) {
    if (!Platform.isWindows) return true;

    try {
      String existingPath = path;
      var dir = Directory(existingPath);
      while (!dir.existsSync()) {
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      existingPath = dir.path;

      return using((arena) {
        final pFreeBytesAvailable = arena<Uint64>();
        final pPath = existingPath.toNativeUtf16(allocator: arena);

        final result = GetDiskFreeSpaceEx(
          pPath,
          pFreeBytesAvailable,
          nullptr,
          nullptr,
        );
        if (result == 0) return true; // Fail gracefully if API returns 0
        return pFreeBytesAvailable.value >= requiredBytes;
      });
    } catch (e) {
      developer.log(
        'Error checking free disk space: $e',
        name: 'UpdateDownloadService',
      );
      return true; // Graceful fallback
    }
  }

  /// Computes the lower-case 64-character SHA-256 hex hash of a file on disk.
  Future<String?> computeFileSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    try {
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString().toLowerCase();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to compute SHA-256 for $filePath: $e',
        name: 'UpdateDownloadService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Checks if an update archive for [version] is already downloaded and cached,
  /// and verifies its SLSA attestation via [releaseService] and expected SHA-256 digest [expectedDigest].
  ///
  /// If the cached file does not exist, or fails SLSA attestation / integrity checks,
  /// the cached file is deleted and `null` is returned.
  Future<String?> getCachedUpdate(
    String version, {
    GitHubReleaseService? releaseService,
    String? expectedDigest,
  }) async {
    final targetFile = File(
      '${updatesDirectory.path}\\Solaris-Windows-v$version.zip',
    );
    if (!await targetFile.exists()) {
      return null;
    }

    final fileHash = await computeFileSha256(targetFile.path);
    if (fileHash == null) {
      await _safeDeleteFile(targetFile);
      return null;
    }

    if (expectedDigest != null && expectedDigest.isNotEmpty) {
      final cleanExpected = expectedDigest
          .replaceFirst('sha256:', '')
          .trim()
          .toLowerCase();
      if (fileHash != cleanExpected) {
        developer.log(
          'Cached update file hash ($fileHash) does not match expected digest ($cleanExpected). Deleting invalid cache.',
          name: 'UpdateDownloadService',
        );
        await _safeDeleteFile(targetFile);
        return null;
      }
    }

    if (releaseService != null) {
      final isAttested = await releaseService.verifyArtifactAttestation(
        fileHash,
      );
      if (!isAttested) {
        developer.log(
          'Cached update file failed SLSA attestation verification ($fileHash). Deleting invalid cache.',
          name: 'UpdateDownloadService',
        );
        await _safeDeleteFile(targetFile);
        return null;
      }
    }

    return targetFile.path;
  }

  Future<void> _safeDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Downloads the update package from [url] into a temporary file (`.zip.tmp`).
  ///
  /// Handles HTTP redirects (301, 302, 307) manually to ensure headers like `X-GitHub-Api-Version`
  /// are NOT passed to third-party CDNs (e.g. AWS S3), avoiding HTTP 400 errors.
  ///
  /// Calls [onProgress] with values from 0.0 to 1.0 during download.
  ///
  /// Returns the path to the temporary downloaded file.
  Future<String> downloadUpdate(
    String url,
    String version, {
    void Function(double progress)? onProgress,
    int? expectedSize,
  }) async {
    final updatesDir = updatesDirectory;
    if (!await updatesDir.exists()) {
      await updatesDir.create(recursive: true);
    }

    final tempFilePath =
        '${updatesDir.path}\\Solaris-Windows-v$version.zip.tmp';
    final tempFile = File(tempFilePath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    // Check disk space before proceeding (minimum 100 MB)
    const minRequiredBytes = 100 * 1024 * 1024;
    if (!hasEnoughDiskSpace(updatesDir.path, minRequiredBytes)) {
      throw InsufficientDiskSpaceException(
        'Insufficient free disk space (minimum 100 MB required)',
      );
    }

    var request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'Solaris-App-Updater/1.0';
    request.followRedirects =
        false; // Isolate GitHub API headers from S3 redirects

    var response = await _client.send(request);

    // Handle HTTP redirects (301, 302, 303, 307, 308) manually with HTTPS and domain validation
    if (response.statusCode == 301 ||
        response.statusCode == 302 ||
        response.statusCode == 303 ||
        response.statusCode == 307 ||
        response.statusCode == 308) {
      final redirectUrl = response.headers['location'];
      if (redirectUrl != null && redirectUrl.isNotEmpty) {
        if (!_isTrustedSecureRedirect(redirectUrl)) {
          throw HttpException(
            'Unsecure or untrusted redirect blocked: $redirectUrl',
            uri: Uri.parse(redirectUrl),
          );
        }
        request = http.Request('GET', Uri.parse(redirectUrl));
        request.headers['User-Agent'] = 'Solaris-App-Updater/1.0';
        response = await _client.send(request);
      }
    }

    if (response.statusCode != 200) {
      throw HttpException(
        'HTTP ${response.statusCode}: Failed to download update file',
        uri: Uri.parse(url),
      );
    }

    final totalBytes = response.contentLength ?? expectedSize ?? 0;
    int downloadedBytes = 0;

    final sink = tempFile.openWrite();

    try {
      await for (final chunk in response.stream) {
        downloadedBytes += chunk.length;
        sink.add(chunk);
        if (totalBytes > 0 && onProgress != null) {
          final progress = downloadedBytes / totalBytes;
          onProgress(progress.clamp(0.0, 1.0));
        }
      }
      await sink.flush();
    } catch (e) {
      await sink.close();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    } finally {
      await sink.close();
    }

    if (expectedSize != null &&
        expectedSize > 0 &&
        downloadedBytes != expectedSize) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      throw HttpException(
        'Downloaded file size ($downloadedBytes B) does not match expected ($expectedSize B)',
      );
    }

    return tempFile.path;
  }

  /// Verifies the SHA-256 integrity of [filePath] against [expectedDigest].
  ///
  /// [expectedDigest] may be prefixed with "sha256:".
  /// Returns `true` if the computed hash matches the expected hash.
  Future<bool> verifyFileIntegrity(
    String filePath,
    String expectedDigest,
  ) async {
    final expectedHash = expectedDigest.replaceFirst('sha256:', '').trim();
    final file = File(filePath);

    if (!await file.exists()) {
      return false;
    }

    try {
      final digest = await sha256.bind(file.openRead()).first;
      final actualHash = digest.toString();
      return actualHash.toLowerCase() == expectedHash.toLowerCase();
    } catch (e, stackTrace) {
      developer.log(
        'Failed to verify file integrity for $filePath: $e',
        name: 'UpdateDownloadService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Promotes a verified temporary file (`.zip.tmp`) to final archive (`.zip`).
  Future<String> finalizeDownload(String tempFilePath, String version) async {
    final finalFilePath =
        '${updatesDirectory.path}\\Solaris-Windows-v$version.zip';
    final tempFile = File(tempFilePath);
    final finalFile = File(finalFilePath);

    if (await finalFile.exists()) {
      await finalFile.delete();
    }

    final renamed = await tempFile.rename(finalFilePath);
    return renamed.path;
  }

  /// Deletes old update archives and temporary files from the updates directory.
  ///
  /// If [keepVersion] is specified, `Solaris-Windows-v{keepVersion}.zip` will be preserved.
  Future<void> cleanupOldDownloads({String? keepVersion}) async {
    final dir = updatesDirectory;
    if (!await dir.exists()) return;

    try {
      final entities = await dir.list().toList();
      final keepFileName = keepVersion != null
          ? 'Solaris-Windows-v$keepVersion.zip'
          : null;

      for (final entity in entities) {
        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          if (keepFileName == null || fileName != keepFileName) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      developer.log(
        'Error cleaning up old downloads: $e',
        name: 'UpdateDownloadService',
      );
    }
  }

  /// Validates that [redirectUrl] uses the HTTPS scheme and targets a trusted domain
  /// (`github.com`, `*.githubusercontent.com`, `*.amazonaws.com`).
  bool _isTrustedSecureRedirect(String redirectUrl) {
    final uri = Uri.tryParse(redirectUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host == 'github.com' ||
        host.endsWith('.github.com') ||
        host == 'githubusercontent.com' ||
        host.endsWith('.githubusercontent.com') ||
        host == 'amazonaws.com' ||
        host.endsWith('.amazonaws.com');
  }
}
