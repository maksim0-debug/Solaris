import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/night_group.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/widgets/sleep_regime_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return '.';
    });
  });

  group('SleepRegimeCard Deletion Widget Tests', () {
    testWidgets('Tapping a sub-session chip opens deletion confirmation dialog with checkbox', (tester) async {
      final session1 = SleepSession(
        id: 'chip_1',
        startTime: DateTime(2026, 7, 25, 18, 4),
        endTime: DateTime(2026, 7, 26, 0, 18),
        source: 'google_fit',
      );
      final session2 = SleepSession(
        id: 'chip_2',
        startTime: DateTime(2026, 7, 26, 1, 0),
        endTime: DateTime(2026, 7, 26, 9, 0),
        source: 'google_fit',
      );

      final nightGroup = NightGroup(
        date: DateTime(2026, 7, 25),
        aggregatedSession: SleepSession(
          id: 'agg',
          startTime: DateTime(2026, 7, 25, 18, 4),
          endTime: DateTime(2026, 7, 26, 9, 0),
        ),
        allSessions: [session1, session2],
      );

      final regime = SleepRegime(
        id: 'regime_1',
        startDate: DateTime(2026, 7, 24),
        endDate: DateTime(2026, 7, 26),
        nights: [nightGroup],
        averageBedtimeNormalized: 1084,
        averageBedtimeFormatted: '18:04',
        averageWakeTimeNormalized: 540,
        averageWakeTimeFormatted: '09:00',
        windowStart: '18:04',
        windowEnd: '18:04',
        anomalyDates: const [],
        isCurrent: true,
        dayCount: 2,
        isFloating: false,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SleepRegimeCard(
                regime: regime,
                initiallyExpanded: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find chip text (e.g. 18:04–00:18)
      final chipFinder = find.text('18:04–00:18');
      expect(chipFinder, findsOneWidget);

      // Tap chip to trigger delete dialog
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Tap Delete button
      final deleteBtn = find.widgetWithText(ElevatedButton, 'Delete');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Verify dialog is closed
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Single tapping row does NOT open dialog, long-pressing row DOES open dialog', (tester) async {
      final session1 = SleepSession(
        id: 'row_s1',
        startTime: DateTime(2026, 7, 25, 18, 4),
        endTime: DateTime(2026, 7, 26, 9, 0),
        source: 'google_fit',
      );

      final nightGroup = NightGroup(
        date: DateTime(2026, 7, 25),
        aggregatedSession: session1,
        allSessions: [session1],
      );

      final regime = SleepRegime(
        id: 'regime_1',
        startDate: DateTime(2026, 7, 24),
        endDate: DateTime(2026, 7, 26),
        nights: [nightGroup],
        averageBedtimeNormalized: 1084,
        averageBedtimeFormatted: '18:04',
        averageWakeTimeNormalized: 540,
        averageWakeTimeFormatted: '09:00',
        windowStart: '18:04',
        windowEnd: '18:04',
        anomalyDates: const [],
        isCurrent: true,
        dayCount: 2,
        isFloating: false,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SleepRegimeCard(
                regime: regime,
                initiallyExpanded: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final rowFinder = find.text('18:04 — 09:00');
      expect(rowFinder, findsOneWidget);

      // Single tap on row should NOT open dialog
      await tester.tap(rowFinder);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      // Long press on row SHOULD open dialog
      await tester.longPress(rowFinder);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
