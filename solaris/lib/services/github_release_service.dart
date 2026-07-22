import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';
import '../models/update_info.dart';

/// Service responsible for fetching release metadata from GitHub Releases API
/// and comparing release versions to determine if an update is available.
class GitHubReleaseService {
  static const String repoOwner = 'maksim0-debug';
  static const String repoName = 'Solaris';
  static const String targetAssetName = 'Solaris-Windows.zip';

  final http.Client _client;

  GitHubReleaseService({http.Client? client}) : _client = client ?? http.Client();

  /// Checks for software updates by querying GitHub Releases API `/releases/latest`.
  ///
  /// Note: The endpoint `/releases/latest` automatically excludes pre-releases.
  ///
  /// Returns [UpdateInfo] if a version strictly greater than [currentVersion] is found,
  /// or `null` if no update is available or an error occurred.
  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$repoOwner/$repoName/releases/latest',
    );

    try {
      final response = await _client.get(
        uri,
        headers: const {
          'User-Agent': 'Solaris-App-Updater/1.0',
          'X-GitHub-Api-Version': '2026-03-10',
          'Accept': 'application/vnd.github+json',
        },
      );

      if (response.statusCode == 200) {
        final jsonMap = json.decode(response.body) as Map<String, dynamic>;
        final updateInfo = UpdateInfo.fromGithubRelease(
          jsonMap,
          targetAssetName: targetAssetName,
        );

        if (updateInfo == null) {
          developer.log(
            'Release asset $targetAssetName not found or invalid in latest release.',
            name: 'GitHubReleaseService',
          );
          return null;
        }

        final isNewer = isVersionNewer(currentVersion, updateInfo.version);
        if (isNewer) {
          return updateInfo;
        } else {
          developer.log(
            'Current version ($currentVersion) is up to date compared to remote (${updateInfo.version}).',
            name: 'GitHubReleaseService',
          );
          return null;
        }
      } else if (response.statusCode == 403) {
        developer.log(
          'GitHub API rate limit exceeded or forbidden (403).',
          name: 'GitHubReleaseService',
        );
        return null;
      } else if (response.statusCode == 404) {
        developer.log(
          'GitHub repository or release not found (404).',
          name: 'GitHubReleaseService',
        );
        return null;
      } else {
        developer.log(
          'GitHub API returned HTTP status ${response.statusCode}',
          name: 'GitHubReleaseService',
        );
        return null;
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error checking for update: $e',
        name: 'GitHubReleaseService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Compares local [currentVersionStr] against remote [remoteVersionStr].
  ///
  /// Returns `true` if remote version is strictly greater than local version.
  /// Correctly handles SemVer build metadata (`+1`) by stripping it before parsing.
  bool isVersionNewer(String currentVersionStr, String remoteVersionStr) {
    try {
      final cleanCurrent = _cleanVersionString(currentVersionStr);
      final cleanRemote = _cleanVersionString(remoteVersionStr);

      final currentSemVer = Version.parse(cleanCurrent);
      final remoteSemVer = Version.parse(cleanRemote);

      return remoteSemVer > currentSemVer;
    } catch (e) {
      developer.log(
        'Version parsing error (current: $currentVersionStr, remote: $remoteVersionStr): $e',
        name: 'GitHubReleaseService',
      );
      return false;
    }
  }

  /// Helper to sanitize version string for `pub_semver` parsing.
  /// Strips leading 'v'/'V' and build metadata suffix (`+1`).
  String _cleanVersionString(String version) {
    var clean = version.trim();
    if (clean.startsWith('v') || clean.startsWith('V')) {
      clean = clean.substring(1);
    }
    // Remove build metadata per SemVer spec (e.g., "1.0.17+1" -> "1.0.17")
    if (clean.contains('+')) {
      clean = clean.split('+').first;
    }
    return clean;
  }
}
