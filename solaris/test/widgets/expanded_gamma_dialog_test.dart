import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/monitor_service.dart';
import 'package:solaris/widgets/expanded_gamma_dialog.dart';

class FakeDialogMonitorService extends MonitorService {
  ExpandedGammaStatus status;
  bool unlockSuccess;
  bool restartSuccess;
  bool restartCalled = false;
  Completer<bool>? unlockCompleter;
  Completer<bool>? restartCompleter;

  FakeDialogMonitorService({
    this.status = ExpandedGammaStatus.disabled,
    this.unlockSuccess = true,
    this.restartSuccess = true,
    this.unlockCompleter,
    this.restartCompleter,
  });

  @override
  Future<ExpandedGammaStatus> getExpandedGammaStatus() async => status;

  @override
  Future<bool> isExpandedGammaUnlocked() async =>
      status == ExpandedGammaStatus.active;

  @override
  Future<bool> unlockExpandedGamma() async {
    if (unlockCompleter != null) {
      final res = await unlockCompleter!.future;
      if (res) status = ExpandedGammaStatus.pendingRestart;
      return res;
    }
    if (unlockSuccess) {
      status = ExpandedGammaStatus.pendingRestart;
    }
    return unlockSuccess;
  }

  @override
  Future<bool> restartComputer() async {
    restartCalled = true;
    if (restartCompleter != null) {
      return await restartCompleter!.future;
    }
    return restartSuccess;
  }
}

void main() {
  group('ExpandedGammaDialog Tests', () {
    testWidgets('Renders dialog initial state and cancels cleanly', (
      tester,
    ) async {
      final fakeService = FakeDialogMonitorService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showExpandedGammaDialog(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNWidgets(2)); // Open + Unlock

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.triangleAlert), findsNothing);
    });

    testWidgets('Unlocking transitions to success and restart buttons', (
      tester,
    ) async {
      final fakeService = FakeDialogMonitorService(unlockSuccess: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showExpandedGammaDialog(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Unlock in Registry
      await tester.tap(find.text('Unlock in Registry'));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
      expect(find.text('Restart Later'), findsOneWidget);
      expect(find.text('Restart Now'), findsOneWidget);

      // Tap Restart Now
      await tester.tap(find.text('Restart Now'));
      await tester.pumpAndSettle();

      expect(fakeService.restartCalled, isTrue);
      expect(find.byIcon(LucideIcons.circleCheck), findsNothing);
    });

    testWidgets('Tapping Restart Later dismisses dialog cleanly', (
      tester,
    ) async {
      final fakeService = FakeDialogMonitorService(unlockSuccess: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showExpandedGammaDialog(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unlock in Registry'));
      await tester.pumpAndSettle();

      // Tap Restart Later
      await tester.tap(find.text('Restart Later'));
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.circleCheck), findsNothing);
    });

    testWidgets(
      'Displays restart failure message when restartComputer returns false',
      (tester) async {
        final fakeService = FakeDialogMonitorService(
          unlockSuccess: true,
          restartSuccess: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showExpandedGammaDialog(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Unlock in Registry'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Restart Now'));
        await tester.pumpAndSettle();

        // Dialog stays open and shows restart failure message
        expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
        expect(
          find.text(
            'Failed to restart computer. Please restart manually to apply changes.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Directly opens in restart pending mode when isPendingRestart is true',
      (tester) async {
        final fakeService = FakeDialogMonitorService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showExpandedGammaDialog(
                      context,
                      isPendingRestart: true,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
        expect(find.text('Restart Later'), findsOneWidget);
        expect(find.text('Restart Now'), findsOneWidget);
      },
    );

    testWidgets(
      'Shows elevating message during unlock and restarting message during restart',
      (tester) async {
        final unlockCompleter = Completer<bool>();
        final restartCompleter = Completer<bool>();
        final fakeService = FakeDialogMonitorService(
          unlockCompleter: unlockCompleter,
          restartCompleter: restartCompleter,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showExpandedGammaDialog(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Tap Unlock in Registry
        await tester.tap(find.text('Unlock in Registry'));
        await tester.pump();

        // While unlock is in-flight, it must show the elevating message
        expect(
          find.text('Requesting Windows administrator rights...'),
          findsOneWidget,
        );
        expect(find.text('Restarting computer...'), findsNothing);

        // Complete the unlock
        unlockCompleter.complete(true);
        await tester.pumpAndSettle();

        expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);

        // Tap Restart Now
        await tester.tap(find.text('Restart Now'));
        await tester.pump();

        // While restart is in-flight, it must show restarting message (NOT elevating)
        expect(find.text('Restarting computer...'), findsOneWidget);
        expect(
          find.text('Requesting Windows administrator rights...'),
          findsNothing,
        );

        // Complete restart
        restartCompleter.complete(true);
        await tester.pumpAndSettle();

        expect(fakeService.restartCalled, isTrue);
      },
    );

    testWidgets(
      'Automatically opens in restart pending mode when provider is pendingRestart without parameter',
      (tester) async {
        final fakeService = FakeDialogMonitorService(
          status: ExpandedGammaStatus.pendingRestart,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showExpandedGammaDialog(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
        expect(find.text('Restart Later'), findsOneWidget);
        expect(find.text('Restart Now'), findsOneWidget);
      },
    );

    testWidgets('PopScope prevents popping dialog while unlock is in-flight', (
      tester,
    ) async {
      final unlockCompleter = Completer<bool>();
      final fakeService = FakeDialogMonitorService(
        unlockCompleter: unlockCompleter,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showExpandedGammaDialog(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Unlock in Registry
      await tester.tap(find.text('Unlock in Registry'));
      await tester.pump();

      // Attempt to pop route - PopScope(canPop: false) must reject it
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.maybePop();
      await tester.pump();

      // Dialog must remain open and showing elevating message
      expect(
        find.text('Requesting Windows administrator rights...'),
        findsOneWidget,
      );

      // Complete unlock
      unlockCompleter.complete(true);
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.circleCheck), findsOneWidget);
    });
  });
}
