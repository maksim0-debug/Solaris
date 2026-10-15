import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/models/circadian_mode.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/services/circadian_service.dart';

import 'helpers/brightness_fixtures.dart';

void main() {
  final service = CircadianService();

  for (final sample in [(850, 1000, 150), (6800, 6500, -300)]) {
    test(
      'temperature ${sample.$1} K reports the range correction separately',
      () {
        final result = service.calculateTargetTemperature(
          brightnessTestPhases(),
          30,
          brightnessTestNoon,
          curvePoints: [
            FlSpot(-20, sample.$1.toDouble()),
            FlSpot(90, sample.$1.toDouble()),
          ],
          circadianMode: CircadianMode.normalizedCurve,
        );
        expect(result.baseTemperature, sample.$1);
        expect(result.finalTemperature, sample.$2);
        expect(result.limitImpact, sample.$3);
        expect(result.roundingImpact, 0);
      },
    );
  }

  for (final sample in [(1002, -1, 1), (1001, 0, -1)]) {
    test(
      'proportional contributions at ${sample.$1} K retain their rounding residual',
      () {
        final result = service.calculateTargetTemperature(
          brightnessTestPhases(),
          30,
          brightnessTestNoon,
          curvePoints: [
            FlSpot(-20, sample.$1.toDouble()),
            FlSpot(90, sample.$1.toDouble()),
          ],
          smartData: const SmartCircadianData(
            windDownTemperatureOffset: -1,
            sleepPressureTemperatureOffset: -1,
            sleepDebtTemperatureOffset: -1,
          ),
        );
        expect(result.finalTemperature, 1000);
        expect(result.windDownImpact, sample.$2);
        expect(result.sleepPressureImpact, sample.$2);
        expect(result.sleepDebtImpact, sample.$2);
        expect(result.limitImpact, 0);
        expect(result.roundingImpact, sample.$3);
        expect(
          result.baseTemperature +
              result.windDownImpact +
              result.sleepPressureImpact +
              result.sleepDebtImpact +
              result.roundingImpact +
              result.limitImpact,
          1000,
        );
      },
    );
  }

  test(
    'rounding metadata participates in equality, copying and neutral reset',
    () {
      const original = SmartCircadianData(
        temperatureLimitImpact: 150,
        temperatureRoundingImpact: 1,
      );
      expect(original.copyWith(), original);
      expect(original.copyWith(temperatureRoundingImpact: -1), isNot(original));
      expect(
        original
            .copyWith(temperatureRoundingImpact: 0)
            .temperatureRoundingImpact,
        0,
      );
      expect(const SmartCircadianData.neutral().temperatureRoundingImpact, 0);
    },
  );

  test(
    'generic interpolation rejects empty data rather than choosing physical units',
    () {
      expect(() => service.interpolateCurve(const [], 0), throwsArgumentError);
    },
  );

  test(
    'generic interpolation preserves both brightness and temperature units',
    () {
      for (final scale in [1.0, 100.0]) {
        final points = [FlSpot(-20, 20 * scale), FlSpot(20, 60 * scale)];
        expect(service.interpolateCurve(points, -30), 20 * scale);
        expect(service.interpolateCurve(points, 0), 40 * scale);
        expect(service.interpolateCurve(points, 30), 60 * scale);
        expect(
          service.interpolateCurve([FlSpot(0, 40 * scale)], 10),
          40 * scale,
        );
      }
    },
  );
}
