import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/update_info.dart';
import 'package:solaris/models/update_status.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/github_release_service.dart';

class CountingMockGitHubService extends GitHubReleaseService {
  int checkCount = 0;
  final UpdateInfo? mockInfo;

  CountingMockGitHubService(this.mockInfo);

  @override
  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    checkCount++;
    return mockInfo;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleUpdateInfo = UpdateInfo(
    version: '1.0.18',
    downloadUrl: 'https://example.com/Solaris-Windows.zip',
    releaseNotes: 'New features added',
    publishedAt: DateTime.now(),
    assetSize: 10240,
    assetDigest: 'sha256:abc123def456',
  );

  group('Auto Update Toggle & Setting Tests', () {
    test('SettingsState initializes isAutoUpdateEnabled correctly', () {
      final state = SettingsState();
      expect(state.isAutoUpdateEnabled, isA<bool>());
    });

    test(
      'SettingsState serialization and copyWith handle isAutoUpdateEnabled',
      () {
        final state = SettingsState(isAutoUpdateEnabled: false);
        expect(state.isAutoUpdateEnabled, isFalse);

        final copy = state.copyWith(isAutoUpdateEnabled: true);
        expect(copy.isAutoUpdateEnabled, isTrue);

        final json = state.toJson();
        expect(json['isAutoUpdateEnabled'], isFalse);

        final restored = SettingsState.fromJson(json);
        expect(restored.isAutoUpdateEnabled, isFalse);
      },
    );

    test(
      'Automatic update check is skipped when isAutoUpdateEnabled is false',
      () async {
        final mockGithub = CountingMockGitHubService(sampleUpdateInfo);
        final container = ProviderContainer(
          overrides: [
            githubReleaseServiceProvider.overrideWithValue(mockGithub),
          ],
        );
        addTearDown(container.dispose);

        // Explicitly set isAutoUpdateEnabled to false
        container
            .read(settingsProvider.notifier)
            .updateAutoUpdateEnabled(false);

        // Perform non-manual check
        await container
            .read(updateProvider.notifier)
            .checkForUpdate(isManual: false);

        // Phase must remain idle and no HTTP/API call executed
        expect(container.read(updateProvider).phase, equals(UpdatePhase.idle));
        expect(mockGithub.checkCount, equals(0));
      },
    );

    test(
      'Manual update check proceeds even when isAutoUpdateEnabled is false',
      () async {
        final mockGithub = CountingMockGitHubService(sampleUpdateInfo);
        final container = ProviderContainer(
          overrides: [
            githubReleaseServiceProvider.overrideWithValue(mockGithub),
          ],
        );
        addTearDown(container.dispose);

        // Explicitly set isAutoUpdateEnabled to false
        container
            .read(settingsProvider.notifier)
            .updateAutoUpdateEnabled(false);

        // Perform manual check
        await container
            .read(updateProvider.notifier)
            .checkForUpdate(isManual: true);

        // State should have updated and mock API called
        expect(mockGithub.checkCount, equals(1));
        expect(
          container.read(updateProvider).phase,
          equals(UpdatePhase.available),
        );
      },
    );
  });
}
