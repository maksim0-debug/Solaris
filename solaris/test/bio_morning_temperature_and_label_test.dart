import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/models/temperature_state.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/l10n/app_localizations_en.dart';
import 'package:solaris/l10n/app_localizations_uk.dart';
import 'package:solaris/widgets/temperature_breakdown_tooltip.dart';

void main() {
  group('Bio-Morning Temperature & Label Verification Tests', () {
    final service = CircadianService();

    final phases = SolarPhaseModel(
      sunrise: DateTime(2026, 3, 19, 6, 0),
      sunset: DateTime(2026, 3, 19, 18, 0),
      goldenHourMorning: DateTime(2026, 3, 19, 5, 30),
      goldenHourMorningEnd: DateTime(2026, 3, 19, 6, 30),
      goldenHourEvening: DateTime(2026, 3, 19, 17, 30),
      goldenHourEveningEnd: DateTime(2026, 3, 19, 18, 30),
      civilTwilightBegin: DateTime(2026, 3, 19, 5, 30),
      civilTwilightEnd: DateTime(2026, 3, 19, 18, 30),
      astronomicalDawn: DateTime(2026, 3, 19, 4, 30),
      civilDusk: DateTime(2026, 3, 19, 18, 30),
      solarNoon: DateTime(2026, 3, 19, 12, 0),
      astronomicalDusk: DateTime(2026, 3, 19, 19, 30),
    );

    // Standard curve with 3300K base at night, 5000K at sunset, 6500K during day
    final curvePoints = [
      const FlSpot(-20, 3300),
      const FlSpot(-6, 3300),
      const FlSpot(0, 5000),
      const FlSpot(10, 6000),
      const FlSpot(30, 6500),
      const FlSpot(90, 6500),
    ];

    test('Bio-Morning provides additive cooling boost to base temperature', () {
      final now = DateTime(2026, 3, 19, 3, 0); // night
      // Simulate Bio-Morning active: factor 0.3, intensity 1.0 -> gap = 6500 - 3300 = 3200K, boost = 3200 * 0.3 = 960K
      const smartData = SmartCircadianData(
        isTimeShiftActive: true,
        timeShiftFactor: 0.3,
        timeShiftTemperatureIntensity: 1.0,
      );

      final result = service.calculateTargetTemperature(
        phases,
        -20.0,
        now,
        curvePoints: curvePoints,
        smartData: smartData,
      );

      expect(result.baseTemperature, 3300);
      expect(result.timeShiftImpact, 960);
      // Final temperature must be 3300 + 960 = 4260K (cooler, not stuck at 3300K)
      expect(result.finalTemperature, 4260);
    });

    test(
      'SmartCircadianData copyWith retains and updates finalTemperature',
      () {
        const initial = SmartCircadianData(
          baseTemperature: 4500,
          timeShiftTemperatureImpact: 365,
          finalTemperature: 4865,
        );

        expect(initial.finalTemperature, 4865);

        final updated = initial.copyWith(finalTemperature: 5000);
        expect(updated.finalTemperature, 5000);
        expect(updated.baseTemperature, 4500);
      },
    );

    test('TemperatureState defaults isSmartCircadianEnabled to true', () {
      final state = TemperatureState();
      expect(state.isSmartCircadianEnabled, isTrue);
      expect(state.isTimeShiftEnabled, isTrue);

      final fromJsonState = TemperatureState.fromJson({});
      expect(fromJsonState.isSmartCircadianEnabled, isTrue);

      final fromJsonDisabled = TemperatureState.fromJson({
        'isSmartCircadianEnabled': false,
        'isTimeShiftEnabled': false,
      });
      expect(fromJsonDisabled.isSmartCircadianEnabled, isFalse);
      expect(fromJsonDisabled.isTimeShiftEnabled, isFalse);
    });

    test('Localization circadianImpact formats signed values properly', () {
      final AppLocalizations l10nEn = AppLocalizationsEn();
      final AppLocalizations l10nUk = AppLocalizationsUk();

      // Bio-Morning positive brightness impact
      const impactPercent = 15;
      final positiveSignStr = impactPercent > 0
          ? '+$impactPercent'
          : '$impactPercent';

      final enMorning = l10nEn.circadianImpactWithTime(
        l10nEn.featureTimeShiftShort,
        positiveSignStr,
        62,
        'm',
      );
      expect(enMorning, contains('+15%'));
      expect(enMorning, 'Bio-Morning +15% brightness (62m)');

      final ukMorning = l10nUk.circadianImpactWithTime(
        l10nUk.featureTimeShiftShort,
        positiveSignStr,
        62,
        'хв',
      );
      expect(ukMorning, contains('+15%'));
      expect(ukMorning, 'Біо-ранок +15% яскравість (62 хв)');

      // Wind-down negative brightness impact
      final negativeSignStr = '-$impactPercent';
      final enWindDown = l10nEn.circadianImpactWithTime(
        l10nEn.featureWindDownShort,
        negativeSignStr,
        62,
        'm',
      );
      expect(enWindDown, contains('-15%'));
      expect(enWindDown, 'Wind-down -15% brightness (62m)');

      // Sleep Pressure negative brightness impact
      final enSleepPressure = l10nEn.circadianImpact(
        l10nEn.featureSleepPressureShort,
        '-10',
      );
      expect(enSleepPressure, contains('-10%'));
      expect(enSleepPressure, 'Sleep Pressure -10% brightness');

      // Sleep Debt negative brightness impact
      final enSleepDebt = l10nEn.circadianImpact(
        l10nEn.featureSleepDebtShort,
        '-15',
      );
      expect(enSleepDebt, contains('-15%'));
      expect(enSleepDebt, 'Sleep Debt -15% brightness');

      // Zero impact must not format with minus sign
      const zeroImpact = 0;
      final zeroSignStr = zeroImpact > 0 ? '-$zeroImpact' : '$zeroImpact';
      final enZeroWindDown = l10nEn.circadianImpact(
        l10nEn.featureWindDownShort,
        zeroSignStr,
      );
      expect(enZeroWindDown, contains('0%'));
      expect(enZeroWindDown, isNot(contains('-0%')));
      expect(enZeroWindDown, 'Wind-down 0% brightness');
    });

    test('All 4 sleep regulations apply temperature changes correctly', () {
      final now = DateTime(
        2026,
        3,
        19,
        18,
        0,
      ); // evening (elevation 0.0 -> base 5000K)

      // 1. Wind-down warming (-400K)
      const windDownData = SmartCircadianData(
        isWindDownActive: true,
        windDownTemperatureOffset: -400,
      );
      final windDownResult = service.calculateTargetTemperature(
        phases,
        0.0,
        now,
        curvePoints: curvePoints,
        smartData: windDownData,
      );
      expect(windDownResult.baseTemperature, 5000);
      expect(windDownResult.windDownImpact, -400);
      expect(windDownResult.finalTemperature, 4600); // 5000 - 400

      // 2. Sleep Pressure warming (-250K)
      const sleepPressureData = SmartCircadianData(
        isSleepPressureActive: true,
        sleepPressureTemperatureOffset: -250,
      );
      final pressureResult = service.calculateTargetTemperature(
        phases,
        0.0,
        now,
        curvePoints: curvePoints,
        smartData: sleepPressureData,
      );
      expect(pressureResult.baseTemperature, 5000);
      expect(pressureResult.sleepPressureImpact, -250);
      expect(pressureResult.finalTemperature, 4750); // 5000 - 250

      // 3. Sleep Debt warming (-500K)
      const sleepDebtData = SmartCircadianData(
        isSleepDebtActive: true,
        sleepDebtTemperatureOffset: -500,
      );
      final debtResult = service.calculateTargetTemperature(
        phases,
        0.0,
        now,
        curvePoints: curvePoints,
        smartData: sleepDebtData,
      );
      expect(debtResult.baseTemperature, 5000);
      expect(debtResult.sleepDebtImpact, -500);
      expect(debtResult.finalTemperature, 4500); // 5000 - 500

      // 4. Bio-Morning cooling boost (+960K)
      const morningData = SmartCircadianData(
        isTimeShiftActive: true,
        timeShiftFactor: 0.3,
        timeShiftTemperatureIntensity: 1.0,
      );
      final morningResult = service.calculateTargetTemperature(
        phases,
        -20.0,
        now,
        curvePoints: curvePoints,
        smartData: morningData,
      );
      expect(morningResult.baseTemperature, 3300);
      expect(morningResult.timeShiftImpact, 960);
      expect(morningResult.finalTemperature, 4260); // 3300 + 960
    });

    testWidgets(
      'TemperatureBreakdownTooltip displays finalTemperature when isSmartCircadianEnabled is true',
      (tester) async {
        const smartData = SmartCircadianData(
          baseTemperature: 3300,
          timeShiftTemperatureImpact: 960,
          finalTemperature: 4260,
          isTimeShiftActive: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: TemperatureBreakdownTooltip(
                smartData: smartData,
                currentTemperature: 5000,
                isSmartCircadianEnabled: true,
                child: Text('Hover Target'),
              ),
            ),
          ),
        );

        final tooltipFinder = find.byType(Tooltip);
        expect(tooltipFinder, findsOneWidget);
        final tooltip = tester.widget<Tooltip>(tooltipFinder);
        final plainText = (tooltip.richMessage as TextSpan).toPlainText();
        expect(plainText, contains('4260 K'));
        expect(plainText, contains('+960 K'));
      },
    );

    testWidgets(
      'TemperatureBreakdownTooltip falls back to currentTemperature when isSmartCircadianEnabled is false',
      (tester) async {
        const smartData = SmartCircadianData(
          baseTemperature: 3300,
          timeShiftTemperatureImpact: 960,
          finalTemperature: 4260,
          isTimeShiftActive: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: TemperatureBreakdownTooltip(
                smartData: smartData,
                currentTemperature: 5000,
                isSmartCircadianEnabled: false,
                child: Text('Hover Target'),
              ),
            ),
          ),
        );

        final tooltipFinder = find.byType(Tooltip);
        expect(tooltipFinder, findsOneWidget);
        final tooltip = tester.widget<Tooltip>(tooltipFinder);
        final plainText = (tooltip.richMessage as TextSpan).toPlainText();
        expect(plainText, contains('5000 K'));
        expect(plainText, isNot(contains('4260 K')));
      },
    );
  });
}
