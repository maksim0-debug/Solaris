import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/widgets/temperature_slider.dart';

void main() {
  group('TemperatureSlider Pure Linear Mapping Tests (1000K..6500K)', () {
    test('Linear 6500K..1000K mapping over full 0.0..1.0 range', () {
      // 6500K = 0.0 (Daylight Blue)
      expect(TemperatureSlider.valueToProgress(value: 6500.0), equals(0.0));
      // Midpoint: (6500 + 1000) / 2 = 3750K = 0.5
      expect(TemperatureSlider.valueToProgress(value: 3750.0), equals(0.5));
      // 1000K = 1.0 (Candlelight Ember)
      expect(TemperatureSlider.valueToProgress(value: 1000.0), equals(1.0));

      // Inverse
      expect(TemperatureSlider.progressToValue(progress: 0.0), equals(6500.0));
      expect(TemperatureSlider.progressToValue(progress: 0.5), equals(3750.0));
      expect(TemperatureSlider.progressToValue(progress: 1.0), equals(1000.0));
    });

    test('Boundary clamping respects 1000K..6500K native limits', () {
      // Below 1000 clamps to 1000 (progress 1.0)
      expect(TemperatureSlider.valueToProgress(value: 500.0), equals(1.0));
      // Above 6500 clamps to 6500 (progress 0.0)
      expect(TemperatureSlider.valueToProgress(value: 7500.0), equals(0.0));

      // Inverse progress clamping
      expect(TemperatureSlider.progressToValue(progress: -0.2), equals(6500.0));
      expect(TemperatureSlider.progressToValue(progress: 1.2), equals(1000.0));
    });

    test(
      'Color transition smoothly interpolates from Blue to Amber to Ember',
      () {
        final blue = TemperatureSlider.progressToColor(0.0);
        expect(blue, equals(const Color(0xFF60A5FA)));

        final amber = TemperatureSlider.progressToColor(0.58);
        expect(amber, equals(const Color(0xFFFDBA74)));

        final ember = TemperatureSlider.progressToColor(1.0);
        expect(ember, equals(const Color(0xFFEA580C)));
      },
    );
  });

  group('TemperatureSlider Widget Interaction Tests', () {
    testWidgets('Renders properly across various temperatures without badges', (
      tester,
    ) async {
      double latestValue = 6500.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SizedBox(
                  width: 400,
                  child: TemperatureSlider(
                    value: latestValue,
                    onChanged: (val) {
                      setState(() {
                        latestValue = val;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(SliderTheme);
      expect(sliderFinder, findsOneWidget);
      expect(find.text('6500K'), findsOneWidget);
    });

    testWidgets(
      'Displays formatted temperature for candle temperature (1500K)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TemperatureSlider(value: 1500.0, onChanged: (_) {}),
            ),
          ),
        );

        expect(find.text('1500K'), findsOneWidget);
      },
    );

    testWidgets('Renders ultra-warm temperature at 1000K', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TemperatureSlider(value: 1000.0, onChanged: (_) {}),
          ),
        ),
      );

      expect(find.text('1000K'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });
  });
}
