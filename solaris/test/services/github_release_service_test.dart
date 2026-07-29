import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solaris/models/update_info.dart';
import 'package:solaris/services/github_release_service.dart';

void main() {
  group('GitHubReleaseService - API Integration & Parsing Tests', () {
    const String validJsonResponse = '''
{
  "tag_name": "v1.0.18",
  "name": "Release v1.0.18",
  "body": "### Changes\\n- Feature X\\n- Bug fix Y",
  "published_at": "2026-07-22T04:00:00Z",
  "assets": [
    {
      "name": "Solaris-Windows.zip",
      "size": 21504000,
      "browser_download_url": "https://github.com/maksim0-debug/Solaris/releases/download/v1.0.18/Solaris-Windows.zip",
      "digest": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    }
  ]
}
''';

    test(
      'checkForUpdate returns UpdateInfo when newer version is available',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.toString(),
            equals(
              'https://api.github.com/repos/maksim0-debug/Solaris/releases/latest',
            ),
          );
          expect(
            request.headers['User-Agent'],
            equals('Solaris-App-Updater/1.0'),
          );
          expect(request.headers['X-GitHub-Api-Version'], equals('2026-03-10'));

          return http.Response(
            validJsonResponse,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final service = GitHubReleaseService(client: mockClient);
        final updateInfo = await service.checkForUpdate('1.0.17+1');

        expect(updateInfo, isNotNull);
        expect(updateInfo!.version, equals('1.0.18'));
        expect(
          updateInfo.downloadUrl,
          equals(
            'https://github.com/maksim0-debug/Solaris/releases/download/v1.0.18/Solaris-Windows.zip',
          ),
        );
        expect(updateInfo.assetSize, equals(21504000));
        expect(
          updateInfo.assetDigest,
          equals(
            'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ),
        );
        expect(updateInfo.releaseNotes, contains('Feature X'));
      },
    );

    test(
      'checkForUpdate returns null when local version is up to date',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(validJsonResponse, 200);
        });

        final service = GitHubReleaseService(client: mockClient);
        final updateInfo = await service.checkForUpdate('1.0.18');

        expect(updateInfo, isNull);
      },
    );

    test('checkForUpdate returns null when target asset is missing', () async {
      const jsonNoZip = '''
{
  "tag_name": "v1.0.18",
  "body": "Notes",
  "published_at": "2026-07-22T04:00:00Z",
  "assets": [
    {
      "name": "OtherApp-Windows.zip",
      "size": 1000,
      "browser_download_url": "https://example.com/other.zip"
    }
  ]
}
''';
      final mockClient = MockClient((request) async {
        return http.Response(jsonNoZip, 200);
      });

      final service = GitHubReleaseService(client: mockClient);
      final updateInfo = await service.checkForUpdate('1.0.17');

      expect(updateInfo, isNull);
    });

    test('checkForUpdate handles HTTP 403 Rate Limit gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('API rate limit exceeded', 403);
      });

      final service = GitHubReleaseService(client: mockClient);
      final updateInfo = await service.checkForUpdate('1.0.17');

      expect(updateInfo, isNull);
    });

    test('checkForUpdate handles HTTP 404 Not Found gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = GitHubReleaseService(client: mockClient);
      final updateInfo = await service.checkForUpdate('1.0.17');

      expect(updateInfo, isNull);
    });

    test(
      'UpdateInfo.releasePageUrl validates github.com domain and scheme',
      () {
        final validInfo = UpdateInfo(
          version: '1.0.18',
          downloadUrl: 'https://example.com/zip',
          releaseNotes: 'Notes',
          publishedAt: DateTime.now(),
          assetSize: 100,
          htmlUrl:
              'https://github.com/maksim0-debug/Solaris/releases/tag/v1.0.18',
        );
        expect(
          validInfo.releasePageUrl,
          equals(
            'https://github.com/maksim0-debug/Solaris/releases/tag/v1.0.18',
          ),
        );

        final maliciousSchemeInfo = UpdateInfo(
          version: '1.0.18',
          downloadUrl: 'https://example.com/zip',
          releaseNotes: 'Notes',
          publishedAt: DateTime.now(),
          assetSize: 100,
          htmlUrl: 'file:///C:/Windows/system32/cmd.exe',
        );
        expect(
          maliciousSchemeInfo.releasePageUrl,
          equals(
            'https://github.com/maksim0-debug/Solaris/releases/tag/v1.0.18',
          ),
        );

        final phishingDomainInfo = UpdateInfo(
          version: '1.0.18',
          downloadUrl: 'https://example.com/zip',
          releaseNotes: 'Notes',
          publishedAt: DateTime.now(),
          assetSize: 100,
          htmlUrl: 'https://phishing-github.com/malicious/tag',
        );
        expect(
          phishingDomainInfo.releasePageUrl,
          equals(
            'https://github.com/maksim0-debug/Solaris/releases/tag/v1.0.18',
          ),
        );
      },
    );

    test(
      'UpdateInfo.fromGithubRelease extracts SHA-256 bound to targetAssetName from release body',
      () {
        final jsonResponse = {
          'tag_name': 'v1.0.18',
          'body':
              'Release notes...\nSolaris-Windows.zip SHA256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\nThanks!',
          'published_at': '2026-07-22T00:00:00Z',
          'assets': [
            {
              'name': 'Solaris-Windows.zip',
              'browser_download_url':
                  'https://objects.githubusercontent.com/Solaris-Windows.zip',
              'size': 1024,
            },
          ],
        };

        final info = UpdateInfo.fromGithubRelease(jsonResponse);
        expect(info, isNotNull);
        expect(
          info!.assetDigest,
          equals(
            'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ),
        );
      },
    );

    test(
      'UpdateInfo.fromGithubRelease ignores SHA-256 bound to other file names in body',
      () {
        final jsonResponse = {
          'tag_name': 'v1.0.18',
          'body':
              'Release notes...\nSolaris-Linux.tar.gz SHA256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\nThanks!',
          'published_at': '2026-07-22T00:00:00Z',
          'assets': [
            {
              'name': 'Solaris-Windows.zip',
              'browser_download_url':
                  'https://objects.githubusercontent.com/Solaris-Windows.zip',
              'size': 1024,
            },
          ],
        };

        final info = UpdateInfo.fromGithubRelease(jsonResponse);
        expect(info, isNotNull);
        expect(info!.assetDigest, isNull);
      },
    );

    test(
      'UpdateInfo.fromGithubRelease leaves assetDigest null when missing from both asset and body',
      () {
        final jsonResponse = {
          'tag_name': 'v1.0.18',
          'body': 'Just release notes without hash',
          'published_at': '2026-07-22T00:00:00Z',
          'assets': [
            {
              'name': 'Solaris-Windows.zip',
              'browser_download_url':
                  'https://objects.githubusercontent.com/Solaris-Windows.zip',
              'size': 1024,
            },
          ],
        };

        final info = UpdateInfo.fromGithubRelease(jsonResponse);
        expect(info, isNotNull);
        expect(info!.assetDigest, isNull);
      },
    );

    test(
      'verifyArtifactAttestation returns true for HTTP 200 with non-empty attestations list',
      () async {
        const validHash =
            'b66c37961131b0e52e3662f154bc68aa2a65a9c367966d2a2cf604056691c013';
        final mockClient = MockClient((request) async {
          expect(
            request.url.toString(),
            equals(
              'https://api.github.com/repos/maksim0-debug/Solaris/attestations/sha256:$validHash',
            ),
          );
          expect(
            request.headers['Accept'],
            equals('application/vnd.github+json'),
          );
          return http.Response('{"attestations": [{"bundle": {}}]}', 200);
        });

        final service = GitHubReleaseService(client: mockClient);
        final isAttested = await service.verifyArtifactAttestation(validHash);

        expect(isAttested, isTrue);
      },
    );

    test(
      'verifyArtifactAttestation returns false for HTTP 404 Not Found (tampered file)',
      () async {
        const tamperedHash =
            '5ba3827a9565f9098ba239192773d14bd6d97f83c4a947534f7baae662f10326';
        final mockClient = MockClient((request) async {
          return http.Response('{"message": "Not Found"}', 404);
        });

        final service = GitHubReleaseService(client: mockClient);
        final isAttested = await service.verifyArtifactAttestation(
          tamperedHash,
        );

        expect(isAttested, isFalse);
      },
    );
  });
}
