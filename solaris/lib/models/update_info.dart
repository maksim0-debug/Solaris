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

  /// Direct URL to GitHub Release page (e.g. "https://github.com/maksim0-debug/Solaris/releases/tag/v1.0.18").
  final String? htmlUrl;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
    required this.assetSize,
    this.assetDigest,
    this.htmlUrl,
  });

  /// Default base URL for GitHub Releases repository.
  static const String defaultReleasesUrl =
      'https://github.com/maksim0-debug/Solaris/releases';

  /// Generates the safe GitHub Release tag URL for a specific version.
  static String getReleaseTagUrl(String version) =>
      '$defaultReleasesUrl/tag/v$version';

  /// Returns a validated and sanitized release URL on GitHub.
  ///
  /// Validates that [htmlUrl] is an HTTP/HTTPS URL belonging to the `github.com` domain.
  /// If invalid, unsafe, or null, falls back to [getReleaseTagUrl].
  String get releasePageUrl {
    if (htmlUrl != null && htmlUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse(htmlUrl!);
        if ((uri.scheme == 'https' || uri.scheme == 'http') &&
            (uri.host == 'github.com' || uri.host.endsWith('.github.com'))) {
          return htmlUrl!;
        }
      } catch (_) {}
    }
    return getReleaseTagUrl(version);
  }

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

      final htmlUrl = json['html_url'] as String?;

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

      var assetDigest = targetAsset['digest'] as String?;
      if (assetDigest == null || assetDigest.isEmpty) {
        assetDigest = _extractDigestFromBody(releaseNotes, targetAssetName);
      }

      return UpdateInfo(
        version: cleanVersion,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        publishedAt: publishedAt,
        assetSize: assetSize,
        assetDigest: assetDigest,
        htmlUrl: htmlUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Extracts a 64-character hex SHA-256 hash strictly associated with [targetAssetName] from [body] if present.
  static String? _extractDigestFromBody(String body, String targetAssetName) {
    if (body.isEmpty || targetAssetName.isEmpty) return null;
    final escapedName = RegExp.escape(targetAssetName);
    final regExp = RegExp(
      '$escapedName[\\s:=]+(?:sha-?256[\\s:=]+)?([a-fA-F0-9]{64})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(body);
    if (match != null) {
      return 'sha256:${match.group(1)!.toLowerCase()}';
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'downloadUrl': downloadUrl,
      'releaseNotes': releaseNotes,
      'publishedAt': publishedAt.toIso8601String(),
      'assetSize': assetSize,
      'assetDigest': assetDigest,
      'htmlUrl': htmlUrl,
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
          assetDigest == other.assetDigest &&
          htmlUrl == other.htmlUrl;

  @override
  int get hashCode =>
      version.hashCode ^
      downloadUrl.hashCode ^
      releaseNotes.hashCode ^
      publishedAt.hashCode ^
      assetSize.hashCode ^
      assetDigest.hashCode ^
      htmlUrl.hashCode;

  @override
  String toString() {
    return 'UpdateInfo(version: $version, downloadUrl: $downloadUrl, assetSize: $assetSize, assetDigest: $assetDigest, htmlUrl: $htmlUrl)';
  }
}
