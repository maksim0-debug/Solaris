import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/solar_phase_blend.dart';
import 'package:solaris/models/solar_phases_config.dart';
import 'package:solaris/services/circadian_service.dart';

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
    now: DateTime(2026, 10, 15, morning ? 8 : 18),
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
    'all four transitions preserve their actual direction and interpolation',
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
      final now = DateTime(2026, 10, 15, morning ? 8 : 18);
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
