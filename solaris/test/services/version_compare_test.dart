import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/github_release_service.dart';

void main() {
  group('GitHubReleaseService - Version Comparison Tests', () {
    late GitHubReleaseService service;

    setUp(() {
      service = GitHubReleaseService();
    });

    test('should return true when remote patch version is higher', () {
      expect(service.isVersionNewer('1.0.17', '1.0.18'), isTrue);
    });

    test('should return true when remote minor version is higher', () {
      expect(service.isVersionNewer('1.0.17', '1.1.0'), isTrue);
    });

    test('should return true when remote major version is higher', () {
      expect(service.isVersionNewer('1.0.17', '2.0.0'), isTrue);
    });

    test('should return false when versions are identical', () {
      expect(service.isVersionNewer('1.0.17', '1.0.17'), isFalse);
    });

    test('should return false when local version is higher', () {
      expect(service.isVersionNewer('1.0.18', '1.0.17'), isFalse);
    });

    test('should handle "v" prefix in remote tag correctly', () {
      expect(service.isVersionNewer('1.0.17', 'v1.0.18'), isTrue);
      expect(service.isVersionNewer('v1.0.17', 'v1.0.17'), isFalse);
    });

    test('should strip build metadata (+1) from local version', () {
      // 1.0.17+1 vs 1.0.18 => 1.0.18 is newer
      expect(service.isVersionNewer('1.0.17+1', '1.0.18'), isTrue);

      // 1.0.17+1 vs 1.0.17 => false (same base semver version)
      expect(service.isVersionNewer('1.0.17+1', '1.0.17'), isFalse);

      // 1.0.17+1 vs v1.0.17+5 => false
      expect(service.isVersionNewer('1.0.17+1', 'v1.0.17+5'), isFalse);
    });

    test('should return false on invalid version string gracefully', () {
      expect(service.isVersionNewer('invalid.version', '1.0.18'), isFalse);
      expect(service.isVersionNewer('1.0.17', 'not_a_version'), isFalse);
    });
  });
}
