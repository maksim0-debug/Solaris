import 'package:meta/meta.dart';

/// Data model representing software update details retrieved from GitHub Releases.
@immutable
class UpdateInfo {
  /// Target version string (e.g. "1.0.18").
  final String version;

  /// Direct URL to download the update package (`Solaris-Windows.zip`).
  final String downloadUrl;

  /// Markdown formatted release notes from GitHub Release body.
  final String releaseNotes;

  /// Date and time when the release was published.
  final DateTime publishedAt;

  /// Size of the release asset file in bytes.
  final int assetSize;

  /// Optional SHA-256 digest from GitHub API (e.g. "sha256:af2b3c4d...").
  final String? assetDigest;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
    required this.assetSize,
    this.assetDigest,
  });

  /// Creates an [UpdateInfo] instance from GitHub Release API JSON response.
  ///
  /// Returns `null` if required fields or the target asset ([targetAssetName]) are missing.
  static UpdateInfo? fromGithubRelease(
    Map<String, dynamic> json, {
    String targetAssetName = 'Solaris-Windows.zip',
  }) {
    try {
      final rawTag = json['tag_name'] as String?;
      if (rawTag == null || rawTag.trim().isEmpty) return null;

      // Strip leading 'v' or 'V' if present (e.g. "v1.0.18" -> "1.0.18")
      var cleanVersion = rawTag.trim();
      if (cleanVersion.startsWith('v') || cleanVersion.startsWith('V')) {
        cleanVersion = cleanVersion.substring(1);
      }

      final releaseNotes = (json['body'] as String?) ?? '';
      final publishedAtStr = json['published_at'] as String?;
      final publishedAt = publishedAtStr != null
          ? DateTime.tryParse(publishedAtStr) ?? DateTime.now()
          : DateTime.now();

      final assets = json['assets'] as List<dynamic>?;
      if (assets == null || assets.isEmpty) return null;

      Map<String, dynamic>? targetAsset;
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = asset['name'] as String?;
          if (name != null && name.toLowerCase() == targetAssetName.toLowerCase()) {
            targetAsset = asset;
            break;
          }
        }
      }

      if (targetAsset == null) return null;

      final downloadUrl = targetAsset['browser_download_url'] as String?;
      final assetSize = targetAsset['size'] as int?;
      if (downloadUrl == null || downloadUrl.isEmpty || assetSize == null) {
        return null;
      }

      final assetDigest = targetAsset['digest'] as String?;

      return UpdateInfo(
        version: cleanVersion,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        publishedAt: publishedAt,
        assetSize: assetSize,
        assetDigest: assetDigest,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'downloadUrl': downloadUrl,
      'releaseNotes': releaseNotes,
      'publishedAt': publishedAt.toIso8601String(),
      'assetSize': assetSize,
      'assetDigest': assetDigest,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateInfo &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          downloadUrl == other.downloadUrl &&
          releaseNotes == other.releaseNotes &&
          publishedAt == other.publishedAt &&
          assetSize == other.assetSize &&
          assetDigest == other.assetDigest;

  @override
  int get hashCode =>
      version.hashCode ^
      downloadUrl.hashCode ^
      releaseNotes.hashCode ^
      publishedAt.hashCode ^
      assetSize.hashCode ^
      assetDigest.hashCode;

  @override
  String toString() {
    return 'UpdateInfo(version: $version, downloadUrl: $downloadUrl, assetSize: $assetSize, assetDigest: $assetDigest)';
  }
}
