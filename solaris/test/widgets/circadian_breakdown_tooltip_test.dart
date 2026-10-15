import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/brightness_target.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/widgets/circadian_breakdown_tooltip.dart';
import 'package:solaris/widgets/temperature_breakdown_tooltip.dart';
import 'package:solaris/services/circadian_service.dart';

import '../helpers/brightness_fixtures.dart';

void main() {
  Future<String> render(
    WidgetTester tester,
    BrightnessTarget target, {
    Locale locale = const Locale('en'),
    double offset = 0,
    double? applied,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: CircadianBreakdownTooltip(
              target: target,
              offset: offset,
              appliedBrightness: applied,
              monitorName: 'Display 1',
              child: const Icon(Icons.info),
            ),
          ),
        ),
      ),
    );
    return tester
        .widget<Tooltip>(find.byType(Tooltip))
        .richMessage!
        .toPlainText();
  }

  BrightnessTarget target(
    BrightnessSource source,
    double base, {
    double? finalValue,
  }) => BrightnessTarget(
    source: source,
    systemPreset: PresetType.brightest,
    data: SmartCircadianData(
      baseBrightness: base,
      finalBrightness: finalValue ?? base,
    ),
  );

  testWidgets(
    'day phases show their source and matching target without a curve preset',
    (tester) async {
      final text = await render(
        tester,
        target(BrightnessSource.solarPhases, 100),
      );
      expect(text, contains('BASE DAY-PHASE BRIGHTNESS: 100%'));
      expect(text, contains('TARGET BRIGHTNESS: 100%'));
      expect(text.toLowerCase(), isNot(contains('curve')));
      expect(text.toLowerCase(), isNot(contains('brightest')));
      expect(text, contains('Monitor: Display 1'));
      final state = tester.state<TooltipState>(find.byType(Tooltip));
      state.ensureTooltipVisible();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a descending curve shows its actual base without a hidden floor',
    (tester) async {
      final text = await render(tester, target(BrightnessSource.curve, 24));
      expect(text, contains('BASE CURVE BRIGHTNESS [BRIGHTEST]: 24%'));
      expect(text, contains('TARGET BRIGHTNESS: 24%'));
      expect(text, isNot(contains('40%')));
    },
  );

  testWidgets('all effective factors appear once in their calculation order', (
    tester,
  ) async {
    final text = await render(
      tester,
      const BrightnessTarget(
        source: BrightnessSource.curve,
        userPresetName: 'My curve',
        data: SmartCircadianData(
          baseBrightness: 80,
          elevationShiftBrightnessImpact: -10,
          weatherAbsoluteImpact: 5,
          windDownAbsoluteImpact: 20,
          sleepPressureAbsoluteImpact: 4,
          sleepDebtAbsoluteImpact: 1,
          timeShiftBrightnessImpact: 30,
          finalBrightness: 70,
        ),
      ),
    );
    final values = ['80%', '-10%', '-5%', '-20%', '-4%', '-1%', '+30%', '70%'];
    var previous = -1;
    for (final value in values) {
      final position = text.indexOf(value);
      expect(position, greaterThan(previous), reason: '$value in $text');
      previous = position;
    }
  });

  testWidgets(
    'monitor offset, upper limit and current applied value are distinct',
    (tester) async {
      final text = await render(
        tester,
        target(BrightnessSource.curve, 95),
        offset: 10,
        applied: 82,
      );
      expect(text, contains('Brightness Offset: +10%'));
      expect(text, contains('Monitor brightness limits: -5%'));
      expect(text, contains('TARGET BRIGHTNESS: 100%'));
      expect(text, contains('Current monitor brightness: 82%'));
    },
  );

  testWidgets('rounding is explained without replacing the computed base', (
    tester,
  ) async {
    final text = await render(tester, target(BrightnessSource.curve, 24.4));
    expect(text, contains(': 24.4%'));
    expect(text, contains('Rounding: -0.4%'));
    expect(text, contains('TARGET BRIGHTNESS: 24%'));
    expect(text, isNot(contains('Current monitor brightness')));
  });

  testWidgets('service limits and monitor limits have distinct labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: CircadianBreakdownTooltip(
            target: BrightnessTarget(
              source: BrightnessSource.curve,
              data: SmartCircadianData(
                baseBrightness: 5,
                brightnessLimitImpact: -5,
                finalBrightness: 0,
              ),
            ),
            minimumBrightness: 20,
            child: Icon(Icons.info),
          ),
        ),
      ),
    );
    final text = tester
        .widget<Tooltip>(find.byType(Tooltip))
        .richMessage!
        .toPlainText();
    expect(text, contains('Brightness limits: -5%'));
    expect(text, contains('Monitor brightness limits: +20%'));
    expect(text, contains('TARGET BRIGHTNESS: 20%'));
  });

  for (final source in [
    BrightnessSource.appFixed,
    BrightnessSource.appCurve,
    BrightnessSource.game,
  ]) {
    testWidgets('$source shows the actual overriding source', (tester) async {
      final text = await render(
        tester,
        BrightnessTarget(
          source: source,
          applicationName: 'Editor',
          userPresetName: 'Editing',
          data: const SmartCircadianData(
            baseBrightness: 55,
            finalBrightness: 55,
          ),
        ),
      );
      expect(text, contains('TARGET BRIGHTNESS: 55%'));
      expect(
        text,
        contains(
          source == BrightnessSource.game
              ? 'GAME MODE BRIGHTNESS'
              : 'APPLICATION RULE [EDITOR]',
        ),
      );
      if (source == BrightnessSource.appCurve) {
        expect(text, contains('[EDITING]'));
      }
      expect(text, isNot(contains('DAY-PHASE')));
    });
  }

  for (final locale in ['uk', 'ru']) {
    testWidgets('phase source is localized for $locale', (tester) async {
      final text = await render(
        tester,
        target(BrightnessSource.solarPhases, 100),
        locale: Locale(locale),
      );
      expect(
        text.toLowerCase(),
        contains(locale == 'uk' ? 'яскравість фаз дня' : 'яркость фаз дня'),
      );
      expect(text, contains('100%'));
    });
  }

  for (final preset in PresetType.values) {
    testWidgets('curve explanation identifies the $preset system preset', (
      tester,
    ) async {
      final text = await render(
        tester,
        BrightnessTarget(
          source: BrightnessSource.curve,
          systemPreset: preset,
          data: const SmartCircadianData(
            baseBrightness: 40,
            finalBrightness: 40,
          ),
        ),
      );
      expect(text, contains('[${preset.name.toUpperCase()}]: 40%'));
      expect(text, contains('TARGET BRIGHTNESS: 40%'));
    });
  }

  testWidgets('calculation bounds and manual source are also explicit', (
    tester,
  ) async {
    var text = await render(
      tester,
      const BrightnessTarget(
        source: BrightnessSource.curve,
        data: SmartCircadianData(
          baseBrightness: 80,
          timeShiftBrightnessImpact: 30,
          brightnessLimitImpact: -10,
          finalBrightness: 100,
        ),
      ),
    );
    expect(text, contains('Brightness limits: -10%'));
    text = await render(tester, target(BrightnessSource.manual, 40));
    expect(text, contains('MANUAL BRIGHTNESS: 40%'));
    expect(text.toLowerCase(), isNot(contains('curve')));
  });

  testWidgets('temperature phases do not claim a curve preset either', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: TemperatureBreakdownTooltip(
            smartData: SmartCircadianData(
              baseTemperature: 6500,
              finalTemperature: 6500,
            ),
            currentTemperature: 6500,
            isSmartCircadianEnabled: false,
            circadianMode: CircadianMode.solarPhases,
            child: Icon(Icons.info),
          ),
        ),
      ),
    );
    final text = tester
        .widget<Tooltip>(find.byType(Tooltip))
        .richMessage!
        .toPlainText();
    expect(text, contains('BASE DAY-PHASE TEMPERATURE: 6500 K'));
    expect(text.toLowerCase(), isNot(contains('curve')));
  });

  for (final sample in [
    (850, 'Temperature limits: +150 K'),
    (1002, 'Rounding: +1 K'),
  ]) {
    testWidgets('temperature explanation distinguishes ${sample.$2}', (
      tester,
    ) async {
      final result = CircadianService().calculateTargetTemperature(
        brightnessTestPhases(),
        30,
        brightnessTestNoon,
        curvePoints: [
          FlSpot(-20, sample.$1.toDouble()),
          FlSpot(90, sample.$1.toDouble()),
        ],
        smartData: sample.$1 == 1002
            ? const SmartCircadianData(
                windDownTemperatureOffset: -1,
                sleepPressureTemperatureOffset: -1,
                sleepDebtTemperatureOffset: -1,
              )
            : const SmartCircadianData.neutral(),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TemperatureBreakdownTooltip(
              smartData: SmartCircadianData(
                baseTemperature: result.baseTemperature,
                finalTemperature: result.finalTemperature,
                windDownTemperatureImpact: result.windDownImpact,
                sleepPressureTemperatureImpact: result.sleepPressureImpact,
                sleepDebtTemperatureImpact: result.sleepDebtImpact,
                temperatureLimitImpact: result.limitImpact,
                temperatureRoundingImpact: result.roundingImpact,
              ),
              currentTemperature: result.finalTemperature,
              isSmartCircadianEnabled: true,
              child: const Icon(Icons.info),
            ),
          ),
        ),
      );
      final text = tester
          .widget<Tooltip>(find.byType(Tooltip))
          .richMessage!
          .toPlainText();
      expect(text, contains(sample.$2));
      expect(text, contains('1000 K'));
      expect(
        text,
        isNot(contains(sample.$1 == 850 ? 'Rounding:' : 'Temperature limits:')),
      );
    });
  }
}
