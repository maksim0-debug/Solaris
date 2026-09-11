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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return '.';
          },
        );
  });

  SleepRegime createTestRegime(int nightCount) {
    final nights = List.generate(nightCount, (index) {
      final date = DateTime(2026, 9, 11).subtract(Duration(days: index));
      return NightGroup(
        date: date,
        aggregatedSession: SleepSession(
          id: 'session_$index',
          startTime: date.add(const Duration(hours: 23)),
          endTime: date.add(const Duration(days: 1, hours: 7)),
        ),
        allSessions: [
          SleepSession(
            id: 'session_${index}_sub',
            startTime: date.add(const Duration(hours: 23)),
            endTime: date.add(const Duration(days: 1, hours: 7)),
          ),
        ],
      );
    });

    return SleepRegime(
      id: 'regime_test',
      startDate: DateTime(2026, 9, 11).subtract(Duration(days: nightCount - 1)),
      endDate: DateTime(2026, 9, 11),
      nights: nights,
      averageBedtimeNormalized: 1380,
      averageBedtimeFormatted: '23:00',
      averageWakeTimeNormalized: 420,
      averageWakeTimeFormatted: '07:00',
      windowStart: '22:00',
      windowEnd: '00:00',
      anomalyDates: const [],
      isCurrent: true,
      dayCount: nightCount,
      isFloating: false,
    );
  }

  Widget createTestWidget({
    required SleepRegime regime,
    int? initialVisibleCount,
  }) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SleepRegimeCard(
              regime: regime,
              initiallyExpanded: true,
              initialVisibleCount: initialVisibleCount,
            ),
          ),
        ),
      ),
    );
  }

  group('SleepRegimeCard Pagination Tests', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(
        1200,
        2400,
      );
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets(
      'When regime nightCount <= initialVisibleCount, all nights shown and no pagination buttons rendered',
      (tester) async {
        final regime = createTestRegime(3);

        await tester.pumpWidget(
          createTestWidget(regime: regime, initialVisibleCount: 5),
        );
        await tester.pumpAndSettle();

        // 3 session rows should be present
        expect(find.byKey(const ValueKey('session_0')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_2')), findsOneWidget);

        // No pagination buttons
        expect(
          find.byKey(const ValueKey('pagination_show_more')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('pagination_show_all')), findsNothing);
        expect(find.byKey(const ValueKey('pagination_collapse')), findsNothing);
      },
    );

    testWidgets(
      'When regime nightCount > initialVisibleCount, only initialVisibleCount shown with load more and ellipsis',
      (tester) async {
        final regime = createTestRegime(8);

        await tester.pumpWidget(
          createTestWidget(regime: regime, initialVisibleCount: 3),
        );
        await tester.pumpAndSettle();

        // Only first 3 sessions should be rendered
        expect(find.byKey(const ValueKey('session_0')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_2')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_3')), findsNothing);
        expect(find.byKey(const ValueKey('session_7')), findsNothing);

        // Show more and Show all must be visible
        expect(
          find.byKey(const ValueKey('pagination_show_more')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('pagination_show_all')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Clicking Show more loads next batch, then remaining, then offers Collapse',
      (tester) async {
        final regime = createTestRegime(7);

        await tester.pumpWidget(
          createTestWidget(regime: regime, initialVisibleCount: 3),
        );
        await tester.pumpAndSettle();

        // Initially 3 items rendered
        expect(find.byKey(const ValueKey('session_0')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_2')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_3')), findsNothing);

        // Click "Show more" (loads next 3 -> total 6)
        await tester.tap(find.byKey(const ValueKey('pagination_show_more')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('session_3')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_5')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_6')), findsNothing);

        // Click "Show more" again (loads remaining 1 -> total 7)
        await tester.tap(find.byKey(const ValueKey('pagination_show_more')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('session_6')), findsOneWidget);

        // All 7 sessions rendered, show_more is gone, collapse is present
        expect(
          find.byKey(const ValueKey('pagination_show_more')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('pagination_collapse')),
          findsOneWidget,
        );

        // Click "Collapse"
        await tester.tap(find.byKey(const ValueKey('pagination_collapse')));
        await tester.pumpAndSettle();

        // Collapsed back to initial 3
        expect(find.byKey(const ValueKey('session_0')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_2')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_3')), findsNothing);
        expect(
          find.byKey(const ValueKey('pagination_show_more')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Clicking Ellipsis (Show all) reveals all sessions immediately',
      (tester) async {
        final regime = createTestRegime(10);

        await tester.pumpWidget(
          createTestWidget(regime: regime, initialVisibleCount: 3),
        );
        await tester.pumpAndSettle();

        // 3 items visible initially
        expect(find.byKey(const ValueKey('session_0')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_3')), findsNothing);

        // Tap ellipsis
        await tester.tap(find.byKey(const ValueKey('pagination_show_all')));
        await tester.pumpAndSettle();

        // All 10 items visible
        expect(find.byKey(const ValueKey('session_0')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_9')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('pagination_collapse')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('pagination_show_more')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'No ArgumentError when defaultLimit > totalNights or when expanding beyond total',
      (tester) async {
        final regime = createTestRegime(8);

        await tester.pumpWidget(
          createTestWidget(regime: regime, initialVisibleCount: 9),
        );
        await tester.pumpAndSettle();

        // All 8 sessions rendered without error
        expect(find.byKey(const ValueKey('session_0')), findsOneWidget);
        expect(find.byKey(const ValueKey('session_7')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('pagination_show_more')),
          findsNothing,
        );
      },
    );
  });
}
