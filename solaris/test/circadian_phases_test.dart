import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:solaris/services/circadian_service.dart';
import 'package:solaris/models/solar_phase_model.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/models/smart_circadian_data.dart';

void main() {
  group('Circadian Phases & Normalized Curve Tests (TDD)', () {
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

    const config = SolarPhasesConfig(
      night: PhaseTarget(brightness: 15.0, temperature: 2200),
      sunrise: PhaseTarget(brightness: 40.0, temperature: 4000),
      day: PhaseTarget(brightness: 100.0, temperature: 6500),
      sunset: PhaseTarget(brightness: 35.0, temperature: 3000),
    );

    test('Winter Zenith: +16° elevation at noon reaches 100% brightness', () {
      final noonWinter = DateTime(2026, 12, 21, 12, 0);
      final brightness = service.calculateBrightnessFromPhases(
        config: config,
        phases: phases,
        elevation: 16.1,
        maxElevation: 16.1,
        minElevation: -63.0,
        now: noonWinter,
      );
      expect(brightness, closeTo(100.0, 0.5));
    });

    test('Summer Zenith: +63° elevation at noon reaches 100% brightness', () {
      final noonSummer = DateTime(2026, 6, 21, 13, 0);
      final brightness = service.calculateBrightnessFromPhases(
        config: config,
        phases: phases,
        elevation: 63.0,
        maxElevation: 63.0,
        minElevation: -16.1,
        now: noonSummer,
      );
      expect(brightness, closeTo(100.0, 0.5));
    });

    test('Summer Nadir: -16.1° at midnight reaches night brightness (15%)', () {
      final midnightSummer = DateTime(2026, 6, 21, 1, 0);
      final brightness = service.calculateBrightnessFromPhases(
        config: config,
        phases: phases,
        elevation: -16.1,
        maxElevation: 63.0,
        minElevation: -16.1,
        now: midnightSummer,
      );
      expect(brightness, closeTo(15.0, 0.5));
    });

    test('Daytime Plateau holds full brightness during high sun hours', () {
      final afternoon = DateTime(2026, 6, 21, 14, 30);
      // Elevation is 48° (well above 50% of 63° max)
      final brightness = service.calculateBrightnessFromPhases(
        config: config,
        phases: phases,
        elevation: 48.0,
        maxElevation: 63.0,
        minElevation: -16.1,
        now: afternoon,
      );
      expect(brightness, closeTo(100.0, 0.5));
    });

    test('Normalized Elevation Maps correctly to curve coordinates', () {
      // In winter, +16.1° max elevation should map to +90° in standard curve space
      final normalizedX = service.normalizeElevationToStandardRange(
        elevation: 16.1,
        minElevation: -63.0,
        maxElevation: 16.1,
      );
      expect(normalizedX, closeTo(90.0, 0.5));

      // At horizon (0°), it maps to around 0°
      final horizonX = service.normalizeElevationToStandardRange(
        elevation: 0.0,
        minElevation: -63.0,
        maxElevation: 16.1,
      );
      expect(horizonX, closeTo(0.0, 1.0));
    });

    test('Temperature calculation from phases matches targets', () {
      final noon = DateTime(2026, 6, 21, 13, 0);
      final tempNoon = service.calculateTemperatureFromPhases(
        config: config,
        phases: phases,
        elevation: 63.0,
        maxElevation: 63.0,
        minElevation: -16.1,
        now: noon,
      );
      expect(tempNoon, 6500);

      final midnight = DateTime(2026, 6, 21, 1, 0);
      final tempNight = service.calculateTemperatureFromPhases(
        config: config,
        phases: phases,
        elevation: -16.1,
        maxElevation: 63.0,
        minElevation: -16.1,
        now: midnight,
      );
      expect(tempNight, 2200);
    });

    test('solarPhases mode ignores curvePoints clamping on night targets', () {
      // Simulate preset with high min clamp (e.g. brightest preset with min 40%, cool with min 3500K)
      const highCurvePoints = [
        FlSpot(-20, 40),
        FlSpot(-6, 60),
        FlSpot(0, 80),
        FlSpot(30, 100),
      ];
      const highTempCurvePoints = [
        FlSpot(-20, 3500),
        FlSpot(-6, 4500),
        FlSpot(0, 5500),
        FlSpot(30, 6500),
      ];

      const customConfig = SolarPhasesConfig(
        night: PhaseTarget(brightness: 10.0, temperature: 2000),
        sunrise: PhaseTarget(brightness: 40.0, temperature: 4000),
        day: PhaseTarget(brightness: 100.0, temperature: 6500),
        sunset: PhaseTarget(brightness: 35.0, temperature: 3000),
      );

      final midnight = DateTime(2026, 3, 19, 1, 0);

      final brightResult = service.calculateTargetBrightness(
        phases,
        -20.0,
        midnight,
        curvePoints: highCurvePoints,
        circadianMode: CircadianMode.solarPhases,
        phasesConfig: customConfig,
        maxElevation: 60.0,
      );

      // Must be 10.0%, NOT clamped to 40.0%
      expect(brightResult.finalBrightness, closeTo(10.0, 0.1));

      final tempResult = service.calculateTargetTemperature(
        phases,
        -20.0,
        midnight,
        curvePoints: highTempCurvePoints,
        circadianMode: CircadianMode.solarPhases,
        phasesConfig: customConfig,
        maxElevation: 60.0,
      );

      // Must be 2000K, NOT clamped to 3500K
      expect(tempResult.finalTemperature, 2000);
    });

    test(
      'SettingsState.fromJson defaults to solarPhases when key is absent',
      () {
        final oldJson = <String, dynamic>{
          'isAutorunEnabled': true,
          'activePreset': 'bright',
        };
        final state = SettingsState.fromJson(oldJson);
        expect(state.circadianMode, CircadianMode.solarPhases);
      },
    );

    test(
      'SettingsState.fromJson migrates legacyDegrees to normalizedCurve',
      () {
        final legacyJson = <String, dynamic>{'circadianMode': 'legacyDegrees'};
        final state = SettingsState.fromJson(legacyJson);
        expect(state.circadianMode, CircadianMode.normalizedCurve);
      },
    );

    test('PhaseTarget.fromJson defensively clamps values', () {
      final corruptedJson = <String, dynamic>{
        'brightness': 150.0,
        'temperature': 9999,
      };
      final target = PhaseTarget.fromJson(corruptedJson);
      expect(target.brightness, 100.0);
      expect(target.temperature, 6500);

      final negativeJson = <String, dynamic>{
        'brightness': -25.0,
        'temperature': 500,
      };
      final targetNeg = PhaseTarget.fromJson(negativeJson);
      expect(targetNeg.brightness, 0.0);
      expect(targetNeg.temperature, 1000);
    });

    test(
      'solarPhases mode allows Wind-down and Sleep Pressure to dim brightness below night base (15%)',
      () {
        final midnight = DateTime(2026, 3, 19, 1, 0);
        const smart = SmartCircadianData(
          brightnessMultiplier: 0.70,
          windDownFactor: 0.70,
          isWindDownActive: true,
        );

        final result = service.calculateTargetBrightness(
          phases,
          -20.0,
          midnight,
          circadianMode: CircadianMode.solarPhases,
          phasesConfig: config,
          smartData: smart,
          maxElevation: 60.0,
        );

        // 15% * 0.70 = 10.5%
        expect(result.finalBrightness, closeTo(10.5, 0.1));
        expect(result.baseBrightness, closeTo(15.0, 0.1));
        expect(result.windDownImpact, closeTo(4.5, 0.1));
      },
    );

    test(
      'solarPhases mode allows Sleep Pressure and Wind-down to warm temperature below night base (2200K)',
      () {
        final midnight = DateTime(2026, 3, 19, 1, 0);
        const smart = SmartCircadianData(
          windDownTemperatureOffset: -400,
          isWindDownActive: true,
        );

        final result = service.calculateTargetTemperature(
          phases,
          -20.0,
          midnight,
          curvePoints: const [],
          circadianMode: CircadianMode.solarPhases,
          phasesConfig: config,
          smartData: smart,
          maxElevation: 60.0,
        );

        // 2200K - 400K = 1800K
        expect(result.finalTemperature, equals(1800));
        expect(result.baseTemperature, equals(2200));
        expect(result.windDownImpact, equals(-400));
      },
    );

    test(
      'solarPhases mode proportionally distributes reductions when multiple factors act at night',
      () {
        final midnight = DateTime(2026, 3, 19, 1, 0);
        // Wind-down 0.80 and Sleep Pressure 0.80 -> multiplier = 0.64
        const smart = SmartCircadianData(
          brightnessMultiplier: 0.64,
          windDownFactor: 0.80,
          sleepPressureFactor: 0.80,
          isWindDownActive: true,
          isSleepPressureActive: true,
        );

        final result = service.calculateTargetBrightness(
          phases,
          -20.0,
          midnight,
          circadianMode: CircadianMode.solarPhases,
          phasesConfig: config,
          smartData: smart,
          maxElevation: 60.0,
        );

        // 15% * 0.64 = 9.6%
        // Total reduction = 15.0 - 9.6 = 5.4%
        // Weights are equal (0.20 each), so impact should be split 50/50: 2.7% each
        expect(result.finalBrightness, closeTo(9.6, 0.1));
        expect(result.windDownImpact, closeTo(2.7, 0.1));
        expect(result.sleepPressureImpact, closeTo(2.7, 0.1));
      },
    );

    test(
      'calculateBrightnessFromPhases strictly bounds output between 0% and 100% with extreme 0% night and 100% day',
      () {
        const extremeConfig = SolarPhasesConfig(
          night: PhaseTarget(brightness: 0.0, temperature: 1000),
          sunrise: PhaseTarget(brightness: 100.0, temperature: 6500),
          day: PhaseTarget(brightness: 100.0, temperature: 6500),
          sunset: PhaseTarget(brightness: 100.0, temperature: 6500),
        );

        for (double elev = -60.0; elev <= 90.0; elev += 0.5) {
          final morningVal = service.calculateBrightnessFromPhases(
            config: extremeConfig,
            phases: phases,
            elevation: elev,
            maxElevation: 60.0,
            minElevation: -60.0,
            now: DateTime(2026, 3, 19, 8, 0),
          );
          expect(morningVal, greaterThanOrEqualTo(0.0));
          expect(morningVal, lessThanOrEqualTo(100.0));

          final eveningVal = service.calculateBrightnessFromPhases(
            config: extremeConfig,
            phases: phases,
            elevation: elev,
            maxElevation: 60.0,
            minElevation: -60.0,
            now: DateTime(2026, 3, 19, 16, 0),
          );
          expect(eveningVal, greaterThanOrEqualTo(0.0));
          expect(eveningVal, lessThanOrEqualTo(100.0));
        }
      },
    );

    test(
      'Midnight continuity: no abrupt jump across 00:00 midnight in white nights',
      () {
        final phasesWith13Noon = SolarPhaseModel(
          sunrise: DateTime(2026, 6, 21, 5, 0),
          sunset: DateTime(2026, 6, 21, 21, 0),
          goldenHourMorning: DateTime(2026, 6, 21, 4, 30),
          goldenHourMorningEnd: DateTime(2026, 6, 21, 5, 30),
          goldenHourEvening: DateTime(2026, 6, 21, 20, 30),
          goldenHourEveningEnd: DateTime(2026, 6, 21, 21, 30),
          civilTwilightBegin: DateTime(2026, 6, 21, 4, 0),
          civilTwilightEnd: DateTime(2026, 6, 21, 22, 0),
          astronomicalDawn: DateTime(2026, 6, 21, 3, 0),
          civilDusk: DateTime(2026, 6, 21, 22, 0),
          solarNoon: DateTime(2026, 6, 21, 13, 0),
          astronomicalDusk: DateTime(2026, 6, 21, 23, 0),
        );

        final beforeMidnight = DateTime(2026, 6, 21, 23, 59);
        final afterMidnight = DateTime(2026, 6, 22, 0, 1);

        final brightBefore = service.calculateBrightnessFromPhases(
          config: config,
          phases: phasesWith13Noon,
          elevation: -3.0,
          maxElevation: 63.0,
          minElevation: -3.0,
          now: beforeMidnight,
        );

        final brightAfter = service.calculateBrightnessFromPhases(
          config: config,
          phases: phasesWith13Noon,
          elevation: -3.0,
          maxElevation: 63.0,
          minElevation: -3.0,
          now: afterMidnight,
        );

        // Before midnight (23:59) and after midnight (00:01) both belong to descending branch towards nadir (01:00)
        expect((brightBefore - brightAfter).abs(), lessThan(0.01));
      },
    );

    test(
      'normalizedCurve mode allows Wind-down and Sleep Pressure to warm temperature below curve baseline',
      () {
        const highTempCurvePoints = [
          FlSpot(-20, 3500),
          FlSpot(0, 5000),
          FlSpot(90, 6500),
        ];

        final midnight = DateTime(2026, 3, 19, 1, 0);
        const smart = SmartCircadianData(
          windDownTemperatureOffset: -600,
          isWindDownActive: true,
        );

        final result = service.calculateTargetTemperature(
          phases,
          -20.0,
          midnight,
          curvePoints: highTempCurvePoints,
          circadianMode: CircadianMode.normalizedCurve,
          smartData: smart,
          maxElevation: 60.0,
        );

        // 3500K - 600K = 2900K. Should not be clamped to 3500K!
        expect(result.finalTemperature, equals(2900));
      },
    );
  });
}
