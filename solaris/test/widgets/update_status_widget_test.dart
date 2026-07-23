import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/update_info.dart';
import 'package:solaris/models/update_status.dart';
import 'package:solaris/providers/app_info_provider.dart';
import 'package:solaris/providers/update_provider.dart';
import 'package:solaris/widgets/update_status_widget.dart';

void main() {
  Widget createTestableWidget({
    required UpdateStatus updateStatus,
    String currentVersion = '1.0.17',
  }) {
    return ProviderScope(
      overrides: [
        updateProvider.overrideWith(() => _FakeUpdateNotifier(updateStatus)),
        appVersionProvider.overrideWith((ref) => currentVersion),
      ],
      child: MaterialApp(
        home: const Scaffold(
          body: Center(
            child: UpdateStatusWidget(),
          ),
        ),
      ),
    );
  }

  testWidgets('renders idle state with version info', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestableWidget(
        updateStatus: const UpdateStatus(phase: UpdatePhase.idle),
        currentVersion: '1.0.17',
      ),
    );

    expect(find.textContaining('1.0.17'), findsOneWidget);
  });

  testWidgets('renders available update state and opens dialog on tap', (WidgetTester tester) async {
    final updateInfo = UpdateInfo(
      version: '1.0.18',
      downloadUrl: 'https://example.com/Solaris-Windows.zip',
      releaseNotes: '### Changes in 1.0.18\n- Bugfixes and improvements',
      publishedAt: DateTime.now(),
      assetSize: 1024 * 1024 * 15,
      assetDigest: 'sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    );

    await tester.pumpWidget(
      createTestableWidget(
        updateStatus: UpdateStatus(
          phase: UpdatePhase.available,
          updateInfo: updateInfo,
        ),
      ),
    );

    expect(find.textContaining('1.0.18'), findsOneWidget);

    // Tap widget to open available update dialog
    await tester.tap(find.byType(UpdateStatusWidget));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('1.0.18'), findsAtLeast(1));
    expect(find.textContaining('15.0 MB'), findsOneWidget);
  });

  testWidgets('clicking Later closes available update dialog without resetting available state', (WidgetTester tester) async {
    final updateInfo = UpdateInfo(
      version: '1.0.18',
      downloadUrl: 'https://example.com/Solaris-Windows.zip',
      releaseNotes: '### Changes in 1.0.18\n- Bugfixes and improvements',
      publishedAt: DateTime.now(),
      assetSize: 1024 * 1024 * 15,
      assetDigest: 'sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
    );

    await tester.pumpWidget(
      createTestableWidget(
        updateStatus: UpdateStatus(
          phase: UpdatePhase.available,
          updateInfo: updateInfo,
        ),
      ),
    );

    // Tap widget to open available update dialog
    await tester.tap(find.byType(UpdateStatusWidget));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Dialog), findsOneWidget);

    // Tap "Later" button
    final laterButton = find.text('Later');
    expect(laterButton, findsOneWidget);
    await tester.tap(laterButton);
    await tester.pump(const Duration(milliseconds: 500));

    // Dialog is dismissed
    expect(find.byType(Dialog), findsNothing);

    // Update status bar widget still shows update version 1.0.18
    expect(find.textContaining('1.0.18'), findsOneWidget);

    // Tapping status bar again opens dialog directly without needing another check
    await tester.tap(find.byType(UpdateStatusWidget));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('15.0 MB'), findsOneWidget);
  });

  testWidgets('renders downloading state with percentage', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestableWidget(
        updateStatus: const UpdateStatus(
          phase: UpdatePhase.downloading,
          downloadProgress: 0.45,
        ),
      ),
    );

    expect(find.textContaining('45%'), findsOneWidget);
  });

  testWidgets('renders ready state and opens install dialog on tap', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestableWidget(
        updateStatus: const UpdateStatus(
          phase: UpdatePhase.ready,
        ),
      ),
    );

    expect(find.byType(UpdateStatusWidget), findsOneWidget);

    // Tap to open install dialog
    await tester.tap(find.byType(UpdateStatusWidget));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('renders error state and opens error dialog on tap', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestableWidget(
        updateStatus: const UpdateStatus(
          phase: UpdatePhase.error,
          errorMessage: 'Checksum verification failed',
        ),
      ),
    );

    expect(find.byType(UpdateStatusWidget), findsOneWidget);

    // Tap to open error dialog
    await tester.tap(find.byType(UpdateStatusWidget));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Checksum verification failed'), findsOneWidget);
  });

  testWidgets('renders checking state with spinner inside dialog', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestableWidget(
        updateStatus: const UpdateStatus(
          phase: UpdatePhase.checking,
        ),
      ),
    );

    await tester.tap(find.byType(UpdateStatusWidget));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Checking for updates...'), findsAtLeast(1));
  });

  testWidgets('renders up to date notice when isUpToDateNotice is true', (WidgetTester tester) async {
    await tester.pumpWidget(
      createTestableWidget(
        updateStatus: const UpdateStatus(
          phase: UpdatePhase.idle,
          isUpToDateNotice: true,
        ),
      ),
    );

    await tester.tap(find.byType(UpdateStatusWidget));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('No updates found'), findsAtLeast(1));
  });
}

class _FakeUpdateNotifier extends UpdateNotifier {
  final UpdateStatus _initialState;

  _FakeUpdateNotifier(this._initialState);

  @override
  UpdateStatus build() {
    return _initialState;
  }
}
