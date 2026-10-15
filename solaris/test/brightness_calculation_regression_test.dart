import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/services/circadian_service.dart';

import 'helpers/brightness_fixtures.dart';

void main() {
  final service = CircadianService();
  final phases = brightnessTestPhases();
  const descendingCurve = [FlSpot(-20, 40), FlSpot(30, 24), FlSpot(90, 20)];

  test('night point does not raise an unadjusted daytime curve value', () {
    final result = service.calculateTargetBrightness(
      phases,
      30,
      brightnessTestNoon,
      curvePoints: descendingCurve,
      circadianMode: CircadianMode.normalizedCurve,
    );
    expect(result.baseBrightness, 24);
    expect(result.finalBrightness, 24);
    expect(result.weatherImpact, 0);
  });

  test('zero weather intensity preserves a curve below its night point', () {
    final result = service.calculateTargetBrightness(
      phases,
      30,
      brightnessTestNoon,
      curvePoints: descendingCurve,
      weather: brightnessTestWeather(),
      weatherIntensity: 0,
    );
    expect(result.finalBrightness, 24);
    expect(result.weatherImpact, 0);
  });

  test('weather uses the minimum of the entire curve without raising it', () {
    final result = service.calculateTargetBrightness(
      phases,
      30,
      brightnessTestNoon,
      curvePoints: descendingCurve,
      weather: brightnessTestWeather(),
    );
    expect(result.finalBrightness, 20);
    expect(result.weatherImpact, 4);
  });

  test('a day phase below the night phase remains the configured target', () {
    final config = SolarPhasesConfig.defaultBalanced.copyWith(
      night: const PhaseTarget(brightness: 40, temperature: 4500),
      day: const PhaseTarget(brightness: 20, temperature: 3000),
    );
    final result = service.calculateTargetBrightness(
      phases,
      60,
      brightnessTestNoon,
      phasesConfig: config,
      maxElevation: 60,
    );
    expect(result.baseBrightness, 20);
    expect(result.finalBrightness, 20);
  });

  test('reductions and morning boost account for the same final value', () {
    final result = service.calculateTargetBrightness(
      phases,
      30,
      brightnessTestNoon,
      curvePoints: const [FlSpot(-20, 20), FlSpot(30, 80), FlSpot(90, 100)],
      smartData: const SmartCircadianData(
        brightnessMultiplier: 0.5,
        windDownFactor: 0.5,
        timeShiftFactor: 0.5,
      ),
    );
    expect(result.finalBrightness, 70);
    expect(result.windDownImpact, 40);
    expect(result.timeShiftImpact, 30);
    expect(
      result.baseBrightness -
          result.weatherImpact -
          result.windDownImpact -
          result.sleepPressureImpact -
          result.sleepDebtImpact +
          result.timeShiftImpact,
      closeTo(result.finalBrightness, 1e-9),
    );
  });

  test('temperature also honors a daytime curve below its first point', () {
    final result = service.calculateTargetTemperature(
      phases,
      30,
      brightnessTestNoon,
      curvePoints: const [
        FlSpot(-20, 4500),
        FlSpot(30, 3000),
        FlSpot(90, 2500),
      ],
      circadianMode: CircadianMode.normalizedCurve,
    );
    expect(result.baseTemperature, 3000);
    expect(result.finalTemperature, 3000);
    expect(result.weatherImpact, 0);
  });

  test(
    'shifted solar elevation is an explicit signed change from the original base',
    () {
      final result = service.calculateTargetBrightness(
        phases,
        0,
        brightnessTestNoon,
        unshiftedElevation: 30,
        curvePoints: const [
          FlSpot(-20, 10),
          FlSpot(0, 40),
          FlSpot(30, 80),
          FlSpot(90, 100),
        ],
      );
      expect(result.baseBrightness, 80);
      expect(result.elevationShiftImpact, -40);
      expect(result.finalBrightness, 40);
    },
  );

  test('weather is inactive at and outside the sunrise to dusk window', () {
    for (final now in [
      phases.sunrise.subtract(const Duration(seconds: 1)),
      phases.sunrise,
      phases.astronomicalDusk,
      phases.astronomicalDusk.add(const Duration(seconds: 1)),
    ]) {
      final result = service.calculateTargetBrightness(
        phases,
        30,
        now,
        curvePoints: const [FlSpot(-20, 10), FlSpot(30, 80), FlSpot(90, 100)],
        weather: brightnessTestWeather(),
      );
      expect(result.finalBrightness, 80, reason: '$now');
      expect(result.weatherImpact, 0, reason: '$now');
    }
  });

  test(
    'temperature weather reports only the reduction allowed by the preset floor',
    () {
      final result = service.calculateTargetTemperature(
        phases,
        30,
        brightnessTestNoon,
        curvePoints: const [
          FlSpot(-20, 2800),
          FlSpot(30, 3000),
          FlSpot(90, 6500),
        ],
        weather: brightnessTestWeather(),
      );
      expect(result.finalTemperature, 2800);
      expect(result.weatherImpact, -200);
      expect(result.limitImpact, 0);
    },
  );

  test('temperature day phases also honor a target below the night phase', () {
    final config = SolarPhasesConfig.defaultBalanced.copyWith(
      night: const PhaseTarget(brightness: 40, temperature: 4500),
      day: const PhaseTarget(brightness: 20, temperature: 3000),
    );
    final result = service.calculateTargetTemperature(
      phases,
      60,
      brightnessTestNoon,
      curvePoints: const [],
      phasesConfig: config,
      maxElevation: 60,
    );
    expect(result.baseTemperature, 3000);
    expect(result.finalTemperature, 3000);
    expect(result.weatherImpact, 0);
  });

  for (final morning in [true, false]) {
    test(
      'temperature phase transitions interpolate on the ${morning ? 'morning' : 'evening'} branch',
      () {
        final now = morning
            ? DateTime(2026, 10, 15, 8)
            : DateTime(2026, 10, 15, 18);
        final expected = <double, int>{
          -6: 2200,
          -3: morning ? 3100 : 2600,
          0: morning ? 4000 : 3000,
          15: morning ? 5250 : 4750,
          30: 6500,
          60: 6500,
        };
        for (final sample in expected.entries) {
          final result = service.calculateTargetTemperature(
            phases,
            sample.key,
            now,
            curvePoints: const [],
            phasesConfig: SolarPhasesConfig.defaultBalanced,
            maxElevation: 60,
          );
          expect(
            result.baseTemperature,
            sample.value,
            reason: 'elevation ${sample.key}',
          );
          expect(
            result.finalTemperature,
            sample.value,
            reason: 'elevation ${sample.key}',
          );
        }
      },
    );
  }

  test(
    'an unavailable temperature curve uses the documented neutral temperature',
    () {
      final result = service.calculateTargetTemperature(
        phases,
        30,
        brightnessTestNoon,
        curvePoints: const [],
        circadianMode: CircadianMode.normalizedCurve,
      );
      expect(result.baseTemperature, 6500);
      expect(result.finalTemperature, 6500);
    },
  );

  test(
    'all brightness contributions reconcile over seeded boundary combinations',
    () {
      final random = math.Random(20261015);
      for (var i = 0; i < 800; i++) {
        final wind = random.nextDouble();
        final pressure = random.nextDouble();
        final debt = random.nextDouble();
        final points = [
          FlSpot(-20, random.nextInt(101).toDouble()),
          FlSpot(0, random.nextInt(101).toDouble()),
          FlSpot(90, random.nextInt(101).toDouble()),
        ];
        final result = service.calculateTargetBrightness(
          phases,
          -20 + random.nextDouble() * 110,
          brightnessTestNoon,
          unshiftedElevation: -20 + random.nextDouble() * 110,
          curvePoints: points,
          weather: i.isEven ? brightnessTestWeather() : null,
          weatherIntensity: random.nextDouble(),
          smartData: SmartCircadianData(
            brightnessMultiplier: (wind * pressure * debt).clamp(0.1, 1),
            windDownFactor: wind,
            sleepPressureFactor: pressure,
            sleepDebtFactor: debt,
            timeShiftFactor: random.nextDouble(),
            timeShiftBrightnessIntensity: random.nextDouble(),
          ),
        );
        expect(
          result.finalBrightness,
          inInclusiveRange(0, 100),
          reason: 'sample $i',
        );
        expect(
          result.weatherImpact,
          greaterThanOrEqualTo(0),
          reason: 'sample $i',
        );
        expect(
          result.baseBrightness +
              result.elevationShiftImpact -
              result.weatherImpact -
              result.windDownImpact -
              result.sleepPressureImpact -
              result.sleepDebtImpact +
              result.timeShiftImpact +
              result.limitImpact,
          closeTo(result.finalBrightness, 1e-8),
          reason: 'sample $i',
        );
      }
    },
  );

  test(
    'all temperature contributions reconcile including clamps and rounding',
    () {
      final random = math.Random(15102026);
      for (var i = 0; i < 500; i++) {
        final points = [
          FlSpot(-20, 1000 + random.nextInt(5501).toDouble()),
          FlSpot(0, 1000 + random.nextInt(5501).toDouble()),
          FlSpot(90, 1000 + random.nextInt(5501).toDouble()),
        ];
        final result = service.calculateTargetTemperature(
          phases,
          random.nextDouble() * 90,
          brightnessTestNoon,
          curvePoints: points,
          weather: i.isEven ? brightnessTestWeather() : null,
          smartData: SmartCircadianData(
            windDownTemperatureOffset: -random.nextInt(4001),
            sleepPressureTemperatureOffset: -random.nextInt(1501),
            sleepDebtTemperatureOffset: -random.nextInt(1001),
            timeShiftFactor: random.nextDouble(),
            timeShiftTemperatureIntensity: random.nextDouble(),
          ),
        );
        expect(result.finalTemperature, inInclusiveRange(1000, 6500));
        expect(
          result.baseTemperature +
              result.weatherImpact +
              result.windDownImpact +
              result.sleepPressureImpact +
              result.sleepDebtImpact +
              result.timeShiftImpact +
              result.limitImpact +
              result.roundingImpact,
          result.finalTemperature,
          reason: 'sample $i',
        );
      }
    },
  );
}
