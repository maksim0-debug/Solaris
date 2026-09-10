import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/models/regime_settings.dart';
import 'package:solaris/models/night_group.dart';
import 'package:solaris/services/regime_analyzer.dart';
import 'package:solaris/widgets/sleep_regime_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('RegimeAnalyzer Ordering and Date Range Tests', () {
    // Replicate user scenario with 7 nights (Sep 3 to Sep 9)
    final sessions = [
      // Sep 3 night: 21:47 - 04:20
      SleepSession(
        id: 's_sep3',
        startTime: DateTime(2026, 9, 3, 21, 47),
        endTime: DateTime(2026, 9, 4, 4, 20),
        title: 'Sep 3',
      ),
      // Sep 4 night: 22:40 - 06:30
      SleepSession(
        id: 's_sep4',
        startTime: DateTime(2026, 9, 4, 22, 40),
        endTime: DateTime(2026, 9, 5, 6, 30),
        title: 'Sep 4',
      ),
      // Sep 5 night (sleeps past midnight): Sep 6 00:13 - 06:32
      SleepSession(
        id: 's_sep5',
        startTime: DateTime(2026, 9, 6, 0, 13),
        endTime: DateTime(2026, 9, 6, 6, 32),
        title: 'Sep 5 night',
      ),
      // Sep 6 night: 22:32 - 07:22
      SleepSession(
        id: 's_sep6',
        startTime: DateTime(2026, 9, 6, 22, 32),
        endTime: DateTime(2026, 9, 7, 7, 22),
        title: 'Sep 6 night',
      ),
      // Sep 7 night: 23:24 - 06:58
      SleepSession(
        id: 's_sep7',
        startTime: DateTime(2026, 9, 7, 23, 24),
        endTime: DateTime(2026, 9, 8, 6, 58),
        title: 'Sep 7 night',
      ),
      // Sep 8 night: 22:59 - 07:13
      SleepSession(
        id: 's_sep8',
        startTime: DateTime(2026, 9, 8, 22, 59),
        endTime: DateTime(2026, 9, 9, 7, 13),
        title: 'Sep 8 night',
      ),
      // Sep 9 night: 22:51 - 07:49
      SleepSession(
        id: 's_sep9',
        startTime: DateTime(2026, 9, 9, 22, 51),
        endTime: DateTime(2026, 9, 10, 7, 49),
        title: 'Sep 9 night',
      ),
    ];

    test('Regime nights are strictly sorted descending (newest first)', () {
      final settings = const RegimeSettings(
        toleranceWindow: 160,
        maxSpread: 99,
        maxAnomalies: 2,
        minRegimeLength: 2,
        anchorSize: 2,
      );

      final regimes = RegimeAnalyzer.analyze(sessions, settings: settings);
      expect(regimes.isNotEmpty, true);

      for (final regime in regimes) {
        // Nights must be in strictly descending chronological order
        for (int i = 0; i < regime.nights.length - 1; i++) {
          final curr = regime.nights[i].aggregatedSession.startTime;
          final next = regime.nights[i + 1].aggregatedSession.startTime;
          expect(
            curr.isAfter(next),
            true,
            reason:
                'Night $curr at index $i must be strictly after night $next at index ${i + 1}',
          );
        }
      }
    });

    test(
      'Regime startDate and endDate accurately span from earliest start to latest end',
      () {
        final settings = const RegimeSettings(
          toleranceWindow: 160,
          maxSpread: 99,
          maxAnomalies: 2,
          minRegimeLength: 2,
          anchorSize: 2,
        );

        final regimes = RegimeAnalyzer.analyze(sessions, settings: settings);
        expect(regimes.isNotEmpty, true);

        final current = regimes.firstWhere(
          (r) => r.isCurrent,
          orElse: () => regimes.first,
        );
        expect(current.startDate.isBefore(current.endDate), true);
        expect(current.endDate, DateTime(2026, 9, 10, 7, 49));
      },
    );

    test(
      'Tolerance monotonicity: increasing tolerance from 115 to 120 does not break single regime',
      () {
        const settings115 = RegimeSettings(
          toleranceWindow: 115,
          maxSpread: 99,
          maxAnomalies: 2,
          minRegimeLength: 2,
          anchorSize: 2,
        );
        const settings120 = RegimeSettings(
          toleranceWindow: 120,
          maxSpread: 99,
          maxAnomalies: 2,
          minRegimeLength: 2,
          anchorSize: 2,
        );

        final regimes115 = RegimeAnalyzer.analyze(
          sessions,
          settings: settings115,
        );
        final regimes120 = RegimeAnalyzer.analyze(
          sessions,
          settings: settings120,
        );

        // In 115, if it forms 1 regime with 7 days, 120 must not split it into more regimes!
        expect(regimes120.length, lessThanOrEqualTo(regimes115.length));
        expect(
          regimes120.first.dayCount,
          greaterThanOrEqualTo(regimes115.first.dayCount),
        );
      },
    );

    test(
      'Strict tolerance (30m) excludes outlier night and responds dynamically',
      () {
        const strictSettings = RegimeSettings(
          toleranceWindow: 30,
          maxSpread: 105,
          maxAnomalies: 2,
          minRegimeLength: 2,
          anchorSize: 2,
        );

        final regimes = RegimeAnalyzer.analyze(
          sessions,
          settings: strictSettings,
        );
        expect(regimes.isNotEmpty, true);
        final current = regimes.first;

        // Sep 3 (21:47) deviates by >30m from the rest of the week, so it is excluded
        expect(current.dayCount, 6);
        expect(current.startDate.day, 4);
        expect(current.endDate.day, 10);
      },
    );

    test(
      'Relaxed tolerance (>=60m) includes outlier night into a single regime',
      () {
        const relaxedSettings = RegimeSettings(
          toleranceWindow: 60,
          maxSpread: 105,
          maxAnomalies: 2,
          minRegimeLength: 2,
          anchorSize: 2,
        );

        final regimes = RegimeAnalyzer.analyze(
          sessions,
          settings: relaxedSettings,
        );
        expect(regimes.isNotEmpty, true);
        final current = regimes.first;

        // Sep 3 is now within the 60m tolerance and maxSpread of 105
        expect(current.dayCount, 7);
        expect(current.startDate.day, 3);
        expect(current.endDate.day, 10);
      },
    );

    test(
      'Strict maxSpread (60m) splits regimes when total bedtime corridor exceeds spread',
      () {
        const tightSpreadSettings = RegimeSettings(
          toleranceWindow: 60,
          maxSpread: 60,
          maxAnomalies: 2,
          minRegimeLength: 2,
          anchorSize: 2,
        );

        final regimes = RegimeAnalyzer.analyze(
          sessions,
          settings: tightSpreadSettings,
        );
        // Total spread across the 7 days is 146 min, which exceeds 60 min spread.
        // It must split into separate regimes.
        expect(regimes.length, 2);
        final current = regimes.first;
        expect(current.dayCount, 3);
        expect(current.startDate.day, 7);
      },
    );

    test(
      'Very relaxed settings (140m tolerance, 180m spread) eliminates all anomalies',
      () {
        const veryRelaxed = RegimeSettings(
          toleranceWindow: 140,
          maxSpread: 180,
          maxAnomalies: 2,
          minRegimeLength: 2,
          anchorSize: 2,
        );

        final regimes = RegimeAnalyzer.analyze(sessions, settings: veryRelaxed);
        expect(regimes.length, 1);
        expect(regimes.first.dayCount, 7);
        expect(regimes.first.anomalyDates, isEmpty);
      },
    );

    testWidgets(
      'SleepRegimeCard header displays full date range matching regime dates',
      (tester) async {
        final regime = SleepRegime(
          id: 'test_regime',
          startDate: DateTime(2026, 9, 6, 0, 13),
          endDate: DateTime(2026, 9, 10, 7, 49),
          averageBedtimeNormalized: 651,
          averageBedtimeFormatted: '22:51',
          averageWakeTimeNormalized: 469,
          averageWakeTimeFormatted: '07:49',
          windowStart: '22:32',
          windowEnd: '00:13',
          anomalyDates: const [],
          isCurrent: true,
          dayCount: 5,
          nights: const [],
          isFloating: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('uk'),
            home: Scaffold(
              body: ProviderScope(child: SleepRegimeCard(regime: regime)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expect to find "6 — 10 вер." and NOT "5 — 6 вер."
        expect(find.textContaining('6 — 10 вер.'), findsOneWidget);
        expect(find.textContaining('5 — 6 вер.'), findsNothing);
      },
    );

    test(
      'Safe fallback: Brand new user with single session history is preserved',
      () {
        final singleSession = [
          SleepSession(
            id: 's_single',
            startTime: DateTime(2026, 9, 10, 23, 0),
            endTime: DateTime(2026, 9, 11, 7, 0),
            title: 'Single session',
          ),
        ];

        final regimes = RegimeAnalyzer.analyze(
          singleSession,
          settings: const RegimeSettings(minRegimeLength: 3),
        );

        expect(regimes.length, 1);
        expect(regimes.first.dayCount, 1);
        expect(regimes.first.startDate, DateTime(2026, 9, 10, 23, 0));
        expect(regimes.first.endDate, DateTime(2026, 9, 11, 7, 0));
      },
    );

    test(
      'Safe fallback: When all regimes are shorter than minRegimeLength, fallback retains them rather than returning empty',
      () {
        // Two sessions separated by days with different bedtimes, neither reaching minRegimeLength (3)
        final sparseSessions = [
          SleepSession(
            id: 's_sparse1',
            startTime: DateTime(2026, 9, 1, 21, 0),
            endTime: DateTime(2026, 9, 2, 5, 0),
          ),
          SleepSession(
            id: 's_sparse2',
            startTime: DateTime(2026, 9, 10, 3, 0),
            endTime: DateTime(2026, 9, 10, 11, 0),
          ),
        ];

        final regimes = RegimeAnalyzer.analyze(
          sparseSessions,
          settings: const RegimeSettings(
            minRegimeLength: 3,
            maxAnomalies: 0,
            toleranceWindow: 30,
          ),
        );

        // Fallback must retain regimes so user data is not erased
        expect(regimes.isNotEmpty, true);
      },
    );

    testWidgets(
      'SleepRegimeCard displays minimalistic anomaly badge and tooltip on anomaly night',
      (tester) async {
        final normalSession = SleepSession(
          id: 's_normal',
          startTime: DateTime(2026, 9, 8, 22, 59),
          endTime: DateTime(2026, 9, 9, 7, 13),
          title: 'Normal night',
        );
        final anomalySession = SleepSession(
          id: 's_anomaly',
          startTime: DateTime(2026, 9, 7, 23, 24),
          endTime: DateTime(2026, 9, 8, 6, 58),
          title: 'Anomaly night',
        );

        final normalNight = NightGroup(
          date: DateTime(2026, 9, 8),
          aggregatedSession: normalSession,
          allSessions: [normalSession],
        );
        final anomalyNight = NightGroup(
          date: DateTime(2026, 9, 7),
          aggregatedSession: anomalySession,
          allSessions: [anomalySession],
        );

        final regime = SleepRegime(
          id: 'regime_with_anomaly',
          startDate: DateTime(2026, 9, 7, 23, 24),
          endDate: DateTime(2026, 9, 9, 7, 13),
          averageBedtimeNormalized: 659,
          averageBedtimeFormatted: '22:59',
          averageWakeTimeNormalized: 433,
          averageWakeTimeFormatted: '07:13',
          windowStart: '22:59',
          windowEnd: '22:59',
          anomalyDates: [DateTime(2026, 9, 7)],
          isCurrent: true,
          dayCount: 2,
          nights: [normalNight, anomalyNight],
          isFloating: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('uk'),
            home: Scaffold(
              body: ProviderScope(
                child: SleepRegimeCard(regime: regime, initiallyExpanded: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expect 1 anomaly badge with text 'Аномалія' and info icon
        expect(find.text('Аномалія'), findsOneWidget);
        expect(find.byIcon(LucideIcons.info), findsOneWidget);

        // Expect tooltip with Ukrainian explanation
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Tooltip &&
                w.message ==
                    'Аномальний час: поодиноке відхилення від звичного графіка',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
