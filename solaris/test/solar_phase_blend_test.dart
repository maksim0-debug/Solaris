import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/solar_phase_blend.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/services/circadian_service.dart';

import 'package:solaris/models/current_day_phase.dart';
import 'package:solaris/services/sun_calculator_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'helpers/brightness_fixtures.dart';

void main() {
  final service = CircadianService();
  final phases = brightnessTestPhases();
  SolarPhaseBlend blend(
    double elevation, {
    bool morning = true,
    double maximum = 60,
  }) => service.resolvePhaseBlend(
    phases: phases,
    elevation: elevation,
    maxElevation: maximum,
    now: DateTime(2026, 10, 15, morning ? 8 : 17),
  );

  test(
    'sunset targets remain active until the astronomical night boundary',
    () {
      const config = SolarPhasesConfig.defaultBalanced;
      for (final now in [
        phases.sunset,
        DateTime(2026, 10, 15, 18, 57),
        phases.civilTwilightEnd,
        phases.astronomicalDusk.subtract(const Duration(microseconds: 1)),
        phases.astronomicalDusk,
        phases.astronomicalDusk.add(const Duration(microseconds: 1)),
        DateTime(2026, 10, 16, 0, 1),
      ]) {
        final isNight = !now.isBefore(phases.astronomicalDusk);
        final target = isNight ? config.night : config.sunset;
        final expected = SolarPhaseBlend.at(
          isNight ? SolarTargetPhase.night : SolarTargetPhase.sunset,
        );
        final brightness = service.calculateTargetBrightness(
          phases,
          -10,
          now,
          phasesConfig: config,
        );
        final temperature = service.calculateTargetTemperature(
          phases,
          -10,
          now,
          curvePoints: const [],
          phasesConfig: config,
        );
        expect(brightness.basePhase, expected, reason: '$now');
        expect(brightness.baseBrightness, target.brightness, reason: '$now');
        expect(brightness.finalBrightness, target.brightness, reason: '$now');
        expect(temperature.basePhase, expected, reason: '$now');
        expect(
          temperature.finalTemperature,
          target.temperature,
          reason: '$now',
        );
      }
    },
  );

  test(
    'Kyiv evening uses sunset until the calculated astronomical dusk',
    () async {
      tz_data.initializeTimeZones();
      final zone = tz.getLocation('Europe/Kyiv');
      final sun = SunCalculatorService();
      final now = tz.TZDateTime(zone, 2026, 10, 15, 18, 57);
      final actual = await sun.calculatePhases(50.45, 30.52, now, zone);
      expect(now.isAfter(actual.civilTwilightEnd), isTrue);
      expect(now.isBefore(actual.astronomicalDusk), isTrue);
      final maximum = sun.getSunElevation(50.45, 30.52, actual.solarNoon);
      for (
        var time = now;
        time.isBefore(actual.astronomicalDusk);
        time = time.add(const Duration(minutes: 1))
      ) {
        final result = service.calculateTargetBrightness(
          actual,
          sun.getSunElevation(50.45, 30.52, time),
          time,
          phasesConfig: SolarPhasesConfig.defaultBalanced,
          maxElevation: maximum,
        );
        expect(result.baseBrightness, 35, reason: '$time');
        expect(
          result.basePhase,
          const SolarPhaseBlend.at(SolarTargetPhase.sunset),
        );
        expect(sun.getCurrentPhase(actual, time), CurrentDayPhase.twilight);
        expect(
          sun.getTimeUntilPhaseEnd(actual, time),
          actual.astronomicalDusk.difference(time),
        );
      }
      final night = service.calculateTargetBrightness(
        actual,
        sun.getSunElevation(50.45, 30.52, actual.astronomicalDusk),
        actual.astronomicalDusk,
        phasesConfig: SolarPhasesConfig.defaultBalanced,
        maxElevation: maximum,
      );
      expect(night.baseBrightness, 15);
      expect(night.basePhase, const SolarPhaseBlend.at(SolarTargetPhase.night));
      expect(
        sun.getCurrentPhase(actual, actual.astronomicalDusk),
        CurrentDayPhase.deepNight,
      );
    },
  );

  test('night and daytime plateaus identify the configured phase', () {
    expect(blend(-6), const SolarPhaseBlend.at(SolarTargetPhase.night));
    expect(blend(-30), const SolarPhaseBlend.at(SolarTargetPhase.night));
    expect(blend(30), const SolarPhaseBlend.at(SolarTargetPhase.day));
    expect(
      blend(60, morning: false),
      const SolarPhaseBlend.at(SolarTargetPhase.day),
    );
  });

  test(
    'the horizon identifies sunrise or sunset from the noon-relative branch',
    () {
      expect(blend(0), const SolarPhaseBlend.at(SolarTargetPhase.sunrise));
      expect(
        blend(0, morning: false),
        const SolarPhaseBlend.at(SolarTargetPhase.sunset),
      );
    },
  );

  test(
    'elevation transitions before sunset preserve direction and interpolation',
    () {
      expect(
        blend(-3),
        const SolarPhaseBlend(
          SolarTargetPhase.night,
          SolarTargetPhase.sunrise,
          0.5,
        ),
      );
      expect(
        blend(15),
        const SolarPhaseBlend(
          SolarTargetPhase.sunrise,
          SolarTargetPhase.day,
          0.5,
        ),
      );
      expect(
        blend(15, morning: false),
        const SolarPhaseBlend(
          SolarTargetPhase.day,
          SolarTargetPhase.sunset,
          0.5,
        ),
      );
      expect(
        blend(-3, morning: false),
        const SolarPhaseBlend(
          SolarTargetPhase.sunset,
          SolarTargetPhase.night,
          0.5,
        ),
      );
      expect(blend(15).brightness(SolarPhasesConfig.defaultBalanced), 70);
      expect(
        blend(
          -3,
          morning: false,
        ).temperature(SolarPhasesConfig.defaultBalanced),
        2600,
      );
    },
  );

  test(
    'the reported phase belongs to the unshifted base rather than the sleep-shifted elevation',
    () {
      final result = service.calculateTargetBrightness(
        phases,
        -3,
        brightnessTestNoon,
        unshiftedElevation: 60,
        maxElevation: 60,
        phasesConfig: SolarPhasesConfig.defaultBalanced,
      );
      expect(result.basePhase, const SolarPhaseBlend.at(SolarTargetPhase.day));
      expect(result.baseBrightness, 100);
      expect(result.elevationShiftImpact, lessThan(0));
    },
  );

  test('phase metadata and numerical results agree throughout the day', () {
    for (final morning in [true, false]) {
      final now = DateTime(2026, 10, 15, morning ? 8 : 17);
      for (var elevation = -20.0; elevation <= 60; elevation += 0.25) {
        final result = service.calculateTargetBrightness(
          phases,
          elevation,
          now,
          maxElevation: 60,
          phasesConfig: SolarPhasesConfig.defaultBalanced,
        );
        final temperature = service.calculateTargetTemperature(
          phases,
          elevation,
          now,
          curvePoints: const [],
          maxElevation: 60,
          phasesConfig: SolarPhasesConfig.defaultBalanced,
        );
        expect(
          result.basePhase!.brightness(SolarPhasesConfig.defaultBalanced),
          result.baseBrightness,
        );
        expect(
          temperature.basePhase!
              .temperature(SolarPhasesConfig.defaultBalanced)
              .round(),
          temperature.baseTemperature,
        );
      }
    }
  });

  test(
    'a small seasonal maximum uses the same plateau boundary as the phase formula',
    () {
      expect(
        blend(1, maximum: 1),
        const SolarPhaseBlend.at(SolarTargetPhase.day),
      );
      expect(blend(0.5, maximum: 1).isTransition, isTrue);
    },
  );
}
