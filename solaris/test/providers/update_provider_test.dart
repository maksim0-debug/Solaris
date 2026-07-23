import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/update_info.dart';
import 'package:solaris/models/update_status.dart';
import 'package:solaris/providers/update_provider.dart';
import 'package:solaris/services/github_release_service.dart';
import 'package:solaris/services/update_download_service.dart';

class MockGitHubReleaseService extends GitHubReleaseService {
  final UpdateInfo? mockInfo;
  final bool mockAttestationResult;

  MockGitHubReleaseService(this.mockInfo, {this.mockAttestationResult = true});

  @override
  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    return mockInfo;
  }

  @override
  Future<bool> verifyArtifactAttestation(String sha256Hash) async {
    return mockAttestationResult;
  }
}

class MockUpdateDownloadService extends UpdateDownloadService {
  final String mockDownloadedPath;
  final bool mockIntegrityResult;

  MockUpdateDownloadService({
    required this.mockDownloadedPath,
    this.mockIntegrityResult = true,
  });

  @override
  Future<String?> computeFileSha256(String filePath) async {
    return 'b66c37961131b0e52e3662f154bc68aa2a65a9c367966d2a2cf604056691c013';
  }

  @override
  Future<String> downloadUpdate(
    String url,
    String version, {
    void Function(double progress)? onProgress,
    int? expectedSize,
  }) async {
    onProgress?.call(0.5);
    onProgress?.call(1.0);
    return mockDownloadedPath;
  }

  @override
  Future<bool> verifyFileIntegrity(String filePath, String expectedDigest) async {
    return mockIntegrityResult;
  }

  @override
  Future<String> finalizeDownload(String tempFilePath, String version) async {
    return mockDownloadedPath.replaceAll('.tmp', '');
  }

  @override
  Future<String?> getCachedUpdate(
    String version, {
    GitHubReleaseService? releaseService,
    String? expectedDigest,
  }) async {
    return null;
  }

  @override
  bool hasEnoughDiskSpace(String path, int requiredBytes) => true;

  @override
  Future<void> cleanupOldDownloads({String? keepVersion}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('solaris_provider_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('UpdateNotifier Riverpod State Unit Tests', () {
    final sampleUpdateInfo = UpdateInfo(
      version: '1.0.18',
      downloadUrl: 'https://example.com/Solaris-Windows.zip',
      releaseNotes: 'New features added',
      publishedAt: DateTime.now(),
      assetSize: 10240,
      assetDigest: 'sha256:abc123def456',
    );

    test('checkForUpdate transitions from idle -> checking -> available', () async {
      final mockGithubService = MockGitHubReleaseService(sampleUpdateInfo);
      final container = ProviderContainer(
        overrides: [
          githubReleaseServiceProvider.overrideWithValue(mockGithubService),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(updateProvider).phase, equals(UpdatePhase.idle));

      final checkFuture = container.read(updateProvider.notifier).checkForUpdate(
            isManual: true,
            currentVersionOverride: '1.0.17',
          );

      await checkFuture;

      final finalState = container.read(updateProvider);
      expect(finalState.phase, equals(UpdatePhase.available));
      expect(finalState.updateInfo?.version, equals('1.0.18'));
    });

    test('startDownload handles downloading, SHA-256 verification and transitions to ready', () async {
      final mockZipFile = File('${tempDir.path}/Solaris-Windows-v1.0.18.zip.tmp');
      await mockZipFile.writeAsString('Dummy Zip');

      final mockGithubService = MockGitHubReleaseService(sampleUpdateInfo);
      final mockDownloadService = MockUpdateDownloadService(
        mockDownloadedPath: mockZipFile.path,
        mockIntegrityResult: true,
      );

      final container = ProviderContainer(
        overrides: [
          githubReleaseServiceProvider.overrideWithValue(mockGithubService),
          updateDownloadServiceProvider.overrideWithValue(mockDownloadService),
        ],
      );
      addTearDown(container.dispose);

      // Setup available update
      await container.read(updateProvider.notifier).checkForUpdate(
            isManual: true,
            currentVersionOverride: '1.0.17',
          );

      // Start download
      await container.read(updateProvider.notifier).startDownload();

      final state = container.read(updateProvider);
      expect(state.phase, equals(UpdatePhase.ready));
      expect(state.downloadedFilePath, equals(mockZipFile.path.replaceAll('.tmp', '')));
      expect(state.downloadProgress, equals(1.0));
    });

    test('startDownload sets error state when SHA-256 integrity verification fails', () async {
      final mockZipFile = File('${tempDir.path}/Solaris-Windows-v1.0.18.zip.tmp');
      await mockZipFile.writeAsString('Corrupted Content');

      final mockGithubService = MockGitHubReleaseService(sampleUpdateInfo);
      final mockDownloadService = MockUpdateDownloadService(
        mockDownloadedPath: mockZipFile.path,
        mockIntegrityResult: false, // Force SHA-256 mismatch
      );

      final container = ProviderContainer(
        overrides: [
          githubReleaseServiceProvider.overrideWithValue(mockGithubService),
          updateDownloadServiceProvider.overrideWithValue(mockDownloadService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateProvider.notifier).checkForUpdate(
            isManual: true,
            currentVersionOverride: '1.0.17',
          );

      await container.read(updateProvider.notifier).startDownload();

      final state = container.read(updateProvider);
      expect(state.phase, equals(UpdatePhase.error));
      expect(state.errorMessage, contains('Integrity verification failed'));
    });

    test('startDownload sets error state when SHA-256 digest is missing from UpdateInfo', () async {
      final mockZipFile = File('${tempDir.path}/Solaris-Windows-v1.0.18.zip.tmp');
      await mockZipFile.writeAsString('Dummy Content');

      final infoWithoutDigest = UpdateInfo(
        version: '1.0.18',
        downloadUrl: 'https://example.com/Solaris-Windows.zip',
        releaseNotes: 'No digest in release notes',
        publishedAt: DateTime.now(),
        assetSize: 10240,
        assetDigest: null, // Missing SHA-256 digest
      );

      final mockGithubService = MockGitHubReleaseService(infoWithoutDigest);
      final mockDownloadService = MockUpdateDownloadService(
        mockDownloadedPath: mockZipFile.path,
      );

      final container = ProviderContainer(
        overrides: [
          githubReleaseServiceProvider.overrideWithValue(mockGithubService),
          updateDownloadServiceProvider.overrideWithValue(mockDownloadService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateProvider.notifier).checkForUpdate(
            isManual: true,
            currentVersionOverride: '1.0.17',
          );

      await container.read(updateProvider.notifier).startDownload();

      final state = container.read(updateProvider);
      expect(state.phase, equals(UpdatePhase.error));
      expect(state.errorMessage, contains('SHA-256 digest is missing from release metadata'));
    });

    test('startDownload sets error state when SLSA provenance attestation check fails', () async {
      final mockZipFile = File('${tempDir.path}/Solaris-Windows-v1.0.18.zip.tmp');
      await mockZipFile.writeAsString('Tampered Content');

      final mockGithubService = MockGitHubReleaseService(
        sampleUpdateInfo,
        mockAttestationResult: false, // Force SLSA attestation check failure (HTTP 404)
      );
      final mockDownloadService = MockUpdateDownloadService(
        mockDownloadedPath: mockZipFile.path,
        mockIntegrityResult: true,
      );

      final container = ProviderContainer(
        overrides: [
          githubReleaseServiceProvider.overrideWithValue(mockGithubService),
          updateDownloadServiceProvider.overrideWithValue(mockDownloadService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateProvider.notifier).checkForUpdate(
            isManual: true,
            currentVersionOverride: '1.0.17',
          );

      await container.read(updateProvider.notifier).startDownload();

      final state = container.read(updateProvider);
      expect(state.phase, equals(UpdatePhase.error));
      expect(state.errorMessage, contains('SLSA attestation'));
    });

    test('dismissUpdate and resetError reset state back to idle', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(updateProvider.notifier).dismissUpdate();
      expect(container.read(updateProvider).phase, equals(UpdatePhase.idle));

      container.read(updateProvider.notifier).resetError();
      expect(container.read(updateProvider).phase, equals(UpdatePhase.idle));
      expect(container.read(updateProvider).errorMessage, isNull);
    });

    test('checkForUpdate sets isUpToDateNotice true when manual check returns no update', () async {
      final mockGithubService = MockGitHubReleaseService(null);
      final container = ProviderContainer(
        overrides: [
          githubReleaseServiceProvider.overrideWithValue(mockGithubService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateProvider.notifier).checkForUpdate(
            isManual: true,
            currentVersionOverride: '1.0.17',
          );

      final state = container.read(updateProvider);
      expect(state.phase, equals(UpdatePhase.idle));
      expect(state.isUpToDateNotice, isTrue);

      container.read(updateProvider.notifier).resetUpToDateNotice();
      expect(container.read(updateProvider).isUpToDateNotice, isFalse);
    });

    test('checkForUpdate leaves isUpToDateNotice false when automatic check returns no update', () async {
      final mockGithubService = MockGitHubReleaseService(null);
      final container = ProviderContainer(
        overrides: [
          githubReleaseServiceProvider.overrideWithValue(mockGithubService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateProvider.notifier).checkForUpdate(
            isManual: false,
            currentVersionOverride: '1.0.17',
          );

      final state = container.read(updateProvider);
      expect(state.phase, equals(UpdatePhase.idle));
      expect(state.isUpToDateNotice, isFalse);
    });
  });
}
