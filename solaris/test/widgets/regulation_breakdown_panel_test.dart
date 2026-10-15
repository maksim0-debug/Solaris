import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/brightness_target.dart';
import 'package:solaris/models/regulation_group.dart';
import 'package:solaris/models/preset_type.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/models/solar_phase_blend.dart';
import 'package:solaris/models/temperature_target.dart';
import 'package:solaris/providers/regulation_breakdown_provider.dart';
import 'package:solaris/widgets/circadian_breakdown_tooltip.dart';
import 'package:solaris/widgets/regulation_breakdown_panel.dart';
import 'package:solaris/widgets/temperature_breakdown_tooltip.dart';

const _day = SolarPhaseBlend.at(SolarTargetPhase.day);
const _base = SmartCircadianData(
  basePhase: _day,
  baseBrightness: 100,
  finalBrightness: 100,
);

MonitorRegulationEntry<BrightnessTarget> _brightness(
  String name, {
  SmartCircadianData data = _base,
  double? applied,
}) => MonitorRegulationEntry(
  id: name,
  name: name,
  appliedValue: applied,
  target: BrightnessTarget(source: BrightnessSource.solarPhases, data: data),
  signature: [data],
);

MonitorRegulationEntry<TemperatureTarget> _temperature(
  String name, {
  int change = 0,
  TemperatureSource source = TemperatureSource.solarPhases,
  SmartCircadianData? data,
}) {
  final calculation =
      data ??
      SmartCircadianData(
        basePhase: _day,
        baseTemperature: 6500,
        finalTemperature: 6500 + change,
        windDownTemperatureImpact: change,
      );
  return MonitorRegulationEntry(
    id: name,
    name: name,
    target: TemperatureTarget(source: source, data: calculation),
    signature: [source, calculation],
  );
}

void main() {
  Future<void> render(
    WidgetTester tester,
    List<MonitorRegulationEntry<BrightnessTarget>> brightness, {
    List<MonitorRegulationEntry<TemperatureTarget>> temperature = const [],
    bool all = true,
    Locale locale = const Locale('en'),
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        regulationBreakdownProvider.overrideWithValue(
          RegulationBreakdownSelection(
            brightness: groupRegulations(brightness),
            temperature: groupRegulations(temperature),
            allSelected: all,
            selectedCount: brightness.length,
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(width: 280, child: RegulationBreakdownPanel()),
            ),
          ),
        ),
      ),
    ),
  );

  List<String> messages(WidgetTester tester) => tester
      .widgetList<Tooltip>(find.byType(Tooltip))
      .map((tooltip) => tooltip.richMessage!.toPlainText())
      .toList();

  testWidgets(
    'identical monitors have one shared check with the specific day phase',
    (tester) async {
      await render(tester, [_brightness('ASUS'), _brightness('LG')]);
      expect(find.byType(CircadianBreakdownTooltip), findsOneWidget);
      final text = messages(tester).single;
      expect(text, startsWith('All Monitors\n'));
      expect(text, contains('BASE DAY BRIGHTNESS: 100%'));
      expect(text, isNot(contains('Monitor: ASUS')));
      expect(find.text('All Monitors'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a secondary-only biological adjustment has its own named check and indicator',
    (tester) async {
      final adjusted = _base.copyWith(
        isTimeShiftActive: true,
        timeShiftBrightnessImpact: -10,
        timeShiftMinutesRemaining: 60,
        finalBrightness: 90,
      );
      await render(tester, [
        _brightness('ASUS'),
        _brightness('LG', data: adjusted),
      ]);
      expect(find.byType(CircadianBreakdownTooltip), findsNWidgets(2));
      final text = messages(tester);
      expect(text[0], contains('Monitor: ASUS'));
      expect(text[0], isNot(contains('Bio-Morning')));
      expect(text[1], contains('Monitor: LG'));
      expect(text[1], contains('Bio-Morning — morning adjustment: -10%'));
      expect(find.text('All Monitors'), findsNothing);
      expect(find.textContaining('Bio-Morning'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing selection removes adjustments belonging to another monitor',
    (tester) async {
      final adjusted = _base.copyWith(
        isTimeShiftActive: true,
        timeShiftBrightnessImpact: -10,
        finalBrightness: 90,
      );
      await render(tester, [_brightness('ASUS')], all: false);
      expect(find.textContaining('Bio-Morning'), findsNothing);
      await render(tester, [_brightness('LG', data: adjusted)], all: false);
      expect(find.textContaining('Bio-Morning'), findsOneWidget);
      expect(messages(tester).single, startsWith('Monitor: LG'));
    },
  );

  for (final sample in [
    (0.6, '+0.6'),
    (-0.6, '-0.6'),
    (1.0, '+1'),
    (0.006, '+0.01'),
    (-0.004, '0'),
    (0.0, '0'),
  ]) {
    testWidgets('Bio-Morning preserves the displayed impact ${sample.$2}', (
      tester,
    ) async {
      final data = _base.copyWith(
        isTimeShiftActive: true,
        elevationShiftBrightnessImpact: sample.$1,
        timeShiftMinutesRemaining: 461,
        baseBrightness: 50,
        finalBrightness: 50 + sample.$1,
      );
      await render(tester, [_brightness('ASUS', data: data)], all: false);
      expect(
        find.text('Bio-Morning ${sample.$2}% brightness (461m)'),
        findsOneWidget,
      );
      final text = messages(tester).single;
      if (sample.$1.abs() >= 0.005) {
        expect(text, contains('Bio-Morning — rhythm shift: ${sample.$2}%'));
      } else {
        expect(text, isNot(contains('rhythm shift')));
      }
    });
  }

  testWidgets('Bio-Morning indicator sums both distinct calculation steps', (
    tester,
  ) async {
    await render(tester, [
      _brightness(
        'ASUS',
        data: _base.copyWith(
          isTimeShiftActive: true,
          elevationShiftBrightnessImpact: -0.65,
          timeShiftBrightnessImpact: 1.25,
          baseBrightness: 99.4,
          finalBrightness: 100,
        ),
      ),
    ], all: false);
    expect(find.text('Bio-Morning +0.6% brightness'), findsOneWidget);
    final text = messages(tester).single;
    expect(text, contains('Bio-Morning — rhythm shift: -0.65%'));
    expect(text, contains('Bio-Morning — morning adjustment: +1.25%'));
    expect(text, contains('TARGET BRIGHTNESS: 100%'));
  });

  testWidgets('all brightness indicators retain fractional contributions', (
    tester,
  ) async {
    await render(tester, [
      _brightness(
        'ASUS',
        data: _base.copyWith(
          weatherAbsoluteImpact: 0.6,
          isWindDownActive: true,
          windDownAbsoluteImpact: 0.25,
          minutesUntilWakeUp: 30,
          isSleepPressureActive: true,
          sleepPressureAbsoluteImpact: 1.2,
          isSleepDebtActive: true,
          sleepDebtAbsoluteImpact: 0.01,
          finalBrightness: 97.94,
        ),
      ),
    ], all: false);
    expect(find.text('Weather: brightness reduced by 0.6%'), findsOneWidget);
    expect(find.textContaining('-0.25% brightness'), findsOneWidget);
    expect(find.textContaining('-1.2% brightness'), findsOneWidget);
    expect(find.textContaining('-0.01% brightness'), findsOneWidget);
    final text = messages(tester).single;
    for (final value in ['-0.6%', '-0.25%', '-1.2%', '-0.01%']) {
      expect(text, contains(value));
    }
  });

  for (final sample in [
    ('uk', 'Біо-ранок', 'зсув ритму', 'ранкова поправка'),
    ('ru', 'Био-утро', 'сдвиг ритма', 'утренняя поправка'),
  ]) {
    testWidgets('Bio-Morning components use consistent names in ${sample.$1}', (
      tester,
    ) async {
      await render(tester, [
        _brightness(
          'ASUS',
          data: _base.copyWith(
            isTimeShiftActive: true,
            elevationShiftBrightnessImpact: 0.35,
            timeShiftBrightnessImpact: 0.25,
            baseBrightness: 99.4,
            finalBrightness: 100,
          ),
        ),
      ], locale: Locale(sample.$1));
      expect(find.textContaining('${sample.$2} +0.6%'), findsOneWidget);
      final text = messages(tester).single;
      expect(text, contains('${sample.$2} — ${sample.$3}: +0.35%'));
      expect(text, contains('${sample.$2} — ${sample.$4}: +0.25%'));
      final state = tester.state<TooltipState>(find.byType(Tooltip));
      state.ensureTooltipVisible();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets('temperature checks split independently of shared brightness', (
    tester,
  ) async {
    await render(
      tester,
      [_brightness('ASUS'), _brightness('LG')],
      temperature: [_temperature('ASUS'), _temperature('LG', change: -400)],
    );
    expect(find.byType(CircadianBreakdownTooltip), findsOneWidget);
    expect(find.byType(TemperatureBreakdownTooltip), findsNWidgets(2));
    final text = messages(tester);
    expect(text[0], startsWith('All Monitors'));
    expect(text[1], contains('Monitor: ASUS'));
    expect(text[1], contains('BASE DAY TEMPERATURE: 6500 K'));
    expect(text[2], contains('Monitor: LG'));
    expect(text[2], contains('-400 K'));
  });

  for (final remaining in [42, 0, -1, null]) {
    testWidgets(
      'temperature Bio-Morning countdown handles $remaining minutes',
      (tester) async {
        await render(
          tester,
          [_brightness('ASUS')],
          temperature: [
            _temperature(
              'ASUS',
              data: SmartCircadianData(
                baseTemperature: 5000,
                finalTemperature: 5250,
                isTimeShiftActive: true,
                timeShiftTemperatureImpact: 250,
                timeShiftMinutesRemaining: remaining,
              ),
            ),
          ],
        );
        expect(
          find.text(
            remaining != null && remaining > 0
                ? 'Bio-Morning: +250 K (42 m)'
                : 'Bio-Morning: +250 K',
          ),
          findsOneWidget,
        );
      },
    );
  }

  for (final source in [TemperatureSource.manual, TemperatureSource.disabled]) {
    testWidgets(
      'mixed temperature regulation explains $source instead of an empty row',
      (tester) async {
        await render(
          tester,
          [_brightness('ASUS'), _brightness('LG')],
          temperature: [
            _temperature('ASUS', change: -400),
            _temperature('LG', source: source),
          ],
        );
        expect(
          find.text(
            source == TemperatureSource.manual
                ? 'Manual control — automatic adjustments paused'
                : 'Temperature control disabled',
          ),
          findsOneWidget,
        );
        expect(
          messages(tester).last,
          contains(
            source == TemperatureSource.manual
                ? 'MANUAL TEMPERATURE'
                : 'TEMPERATURE CONTROL DISABLED',
          ),
        );
      },
    );
  }

  testWidgets('mixed brightness regulation explains a manual monitor', (
    tester,
  ) async {
    final manual = MonitorRegulationEntry(
      id: 'LG',
      name: 'LG',
      target: const BrightnessTarget(
        source: BrightnessSource.manual,
        data: _base,
      ),
      signature: const [BrightnessSource.manual],
    );
    await render(tester, [_brightness('ASUS'), manual]);
    expect(
      find.text('Manual control — automatic adjustments paused'),
      findsOneWidget,
    );
    expect(messages(tester).last, contains('MANUAL BRIGHTNESS'));
  });

  testWidgets(
    'fully manual or disabled selections keep regulation sections hidden',
    (tester) async {
      await render(
        tester,
        [
          MonitorRegulationEntry(
            id: 'LG',
            name: 'LG',
            target: const BrightnessTarget(
              source: BrightnessSource.manual,
              data: _base,
            ),
            signature: const [BrightnessSource.manual],
          ),
        ],
        temperature: [_temperature('LG', source: TemperatureSource.disabled)],
      );
      expect(find.byType(Tooltip), findsNothing);
      expect(
        find.text('Manual control — automatic adjustments paused'),
        findsNothing,
      );
      expect(find.text('Temperature control disabled'), findsNothing);
    },
  );

  testWidgets(
    'a shared target still reports different in-progress values for each monitor',
    (tester) async {
      await render(tester, [
        _brightness('ASUS', applied: 80),
        _brightness('LG', applied: 70),
      ]);
      final text = messages(tester).single;
      expect(text, contains('Current monitor brightness [ASUS]: 80%'));
      expect(text, contains('Current monitor brightness [LG]: 70%'));
      expect(text, contains('TARGET BRIGHTNESS: 100%'));
      expect(find.byType(CircadianBreakdownTooltip), findsOneWidget);
    },
  );

  testWidgets(
    'a partial selection uses the selected names rather than all monitors',
    (tester) async {
      await render(tester, [
        _brightness('ASUS'),
        _brightness('LG'),
      ], all: false);
      expect(messages(tester).single, startsWith('ASUS, LG'));
      expect(find.text('All Monitors'), findsNothing);
    },
  );

  testWidgets(
    'an application temperature preset does not inherit the inactive global preset label',
    (tester) async {
      final data = SmartCircadianData(
        baseTemperature: 4200,
        finalTemperature: 4200,
        activeUserTemperaturePresetName: 'Inactive global preset',
      );
      final target = TemperatureTarget(
        source: TemperatureSource.appCurve,
        data: data,
        systemPreset: TemperaturePresetType.custom,
        applicationName: 'Editor',
      );
      await render(
        tester,
        [_brightness('ASUS')],
        all: false,
        temperature: [
          MonitorRegulationEntry(
            id: 'ASUS',
            name: 'ASUS',
            target: target,
            signature: [data],
          ),
        ],
      );
      final text = messages(tester).last;
      expect(text, contains('APPLICATION RULE [EDITOR]'));
      expect(text, contains('[CUSTOM]'));
      expect(text, isNot(contains('Inactive global preset')));
    },
  );

  for (final locale in ['uk', 'ru']) {
    testWidgets('shared checks and phase names are localized for $locale', (
      tester,
    ) async {
      await render(tester, [
        _brightness('ASUS'),
        _brightness('LG'),
      ], locale: Locale(locale));
      final text = messages(tester).single.toLowerCase();
      expect(text, contains(locale == 'uk' ? 'усі монітори' : 'все мониторы'));
      expect(
        text,
        contains(
          locale == 'uk' ? 'базова яскравість дня' : 'базовая яркость дня',
        ),
      );
    });
  }

  for (final sample in [
    (SolarTargetPhase.night, 15.0, 'NIGHT'),
    (SolarTargetPhase.sunrise, 40.0, 'SUNRISE'),
    (SolarTargetPhase.day, 100.0, 'DAY'),
    (SolarTargetPhase.sunset, 35.0, 'SUNSET'),
  ]) {
    testWidgets(
      'the configured ${sample.$3} phase has its specific base label',
      (tester) async {
        final data = _base.copyWith(
          basePhase: SolarPhaseBlend.at(sample.$1),
          baseBrightness: sample.$2,
          finalBrightness: sample.$2,
        );
        await render(tester, [_brightness('ASUS', data: data)], all: false);
        expect(
          messages(tester).single,
          contains('BASE ${sample.$3} BRIGHTNESS: ${sample.$2.round()}%'),
        );
      },
    );
  }

  testWidgets('transition names describe the actual intermediate base value', (
    tester,
  ) async {
    final data = _base.copyWith(
      basePhase: const SolarPhaseBlend(
        SolarTargetPhase.day,
        SolarTargetPhase.sunset,
        0.5,
      ),
      baseBrightness: 67.5,
      finalBrightness: 67.5,
    );
    await render(tester, [_brightness('ASUS', data: data)], all: false);
    expect(
      messages(tester).single,
      contains('BASE BRIGHTNESS (DAY → SUNSET): 67.5%'),
    );
  });

  testWidgets('long monitor names wrap within the dashboard card width', (
    tester,
  ) async {
    final data = _base.copyWith(finalBrightness: 90, weatherAbsoluteImpact: 10);
    await render(tester, [
      _brightness('A very long monitor model name with several identifiers'),
      _brightness(
        'Another long monitor model name for a different display',
        data: data,
      ),
    ]);
    for (final state in tester.stateList<TooltipState>(find.byType(Tooltip))) {
      state.ensureTooltipVisible();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      Tooltip.dismissAllToolTips();
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
