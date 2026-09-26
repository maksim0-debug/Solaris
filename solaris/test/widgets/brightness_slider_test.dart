import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/widgets/brightness_slider.dart';

void main() {
  group('BrightnessSlider 25% Overlay / 75% Physical Mapping Tests', () {
    test(
      'Software dimming disabled: linear 0..100% mapping over full 0.0..1.0 range',
      () {
        expect(
          BrightnessSlider.valueToProgress(
            value: 0.0,
            isSoftwareDimmingEnabled: false,
          ),
          equals(0.0),
        );
        expect(
          BrightnessSlider.valueToProgress(
            value: 50.0,
            isSoftwareDimmingEnabled: false,
          ),
          equals(0.5),
        );
        expect(
          BrightnessSlider.valueToProgress(
            value: 100.0,
            isSoftwareDimmingEnabled: false,
          ),
          equals(1.0),
        );

        expect(
          BrightnessSlider.progressToValue(
            progress: 0.0,
            isSoftwareDimmingEnabled: false,
          ),
          equals(0.0),
        );
        expect(
          BrightnessSlider.progressToValue(
            progress: 0.5,
            isSoftwareDimmingEnabled: false,
          ),
          equals(50.0),
        );
        expect(
          BrightnessSlider.progressToValue(
            progress: 1.0,
            isSoftwareDimmingEnabled: false,
          ),
          equals(100.0),
        );
      },
    );

    test(
      'Software dimming enabled: 25% of slider width is allocated to -100%..0%',
      () {
        // Far-left: -100% brightness is at progress 0.0
        expect(
          BrightnessSlider.valueToProgress(
            value: -100.0,
            isSoftwareDimmingEnabled: true,
          ),
          equals(0.0),
        );

        // Mid-overlay: -50% brightness is at progress 0.125 (half of the 25% zone)
        expect(
          BrightnessSlider.valueToProgress(
            value: -50.0,
            isSoftwareDimmingEnabled: true,
          ),
          equals(0.125),
        );

        // Zero-notch: 0% brightness is EXACTLY at progress 0.25 (25% of slider width)
        expect(
          BrightnessSlider.valueToProgress(
            value: 0.0,
            isSoftwareDimmingEnabled: true,
          ),
          equals(0.25),
        );

        // Mid-hardware: 50% physical brightness is at progress 0.25 + 0.5 * 0.75 = 0.625
        expect(
          BrightnessSlider.valueToProgress(
            value: 50.0,
            isSoftwareDimmingEnabled: true,
          ),
          equals(0.625),
        );

        // Far-right: 100% physical brightness is at progress 1.0
        expect(
          BrightnessSlider.valueToProgress(
            value: 100.0,
            isSoftwareDimmingEnabled: true,
          ),
          equals(1.0),
        );
      },
    );

    test(
      'Software dimming enabled: progressToValue inverses correctly across both zones',
      () {
        expect(
          BrightnessSlider.progressToValue(
            progress: 0.0,
            isSoftwareDimmingEnabled: true,
          ),
          equals(-100.0),
        );
        expect(
          BrightnessSlider.progressToValue(
            progress: 0.125,
            isSoftwareDimmingEnabled: true,
          ),
          equals(-50.0),
        );
        expect(
          BrightnessSlider.progressToValue(
            progress: 0.25,
            isSoftwareDimmingEnabled: true,
          ),
          equals(0.0),
        );
        expect(
          BrightnessSlider.progressToValue(
            progress: 0.625,
            isSoftwareDimmingEnabled: true,
          ),
          equals(50.0),
        );
        expect(
          BrightnessSlider.progressToValue(
            progress: 1.0,
            isSoftwareDimmingEnabled: true,
          ),
          equals(100.0),
        );
      },
    );

    test(
      'Property-based round-trip: valueToProgress -> progressToValue preserves values within tolerance',
      () {
        for (double v = -100.0; v <= 100.0; v += 1.0) {
          final progress = BrightnessSlider.valueToProgress(
            value: v,
            isSoftwareDimmingEnabled: true,
          );
          final restored = BrightnessSlider.progressToValue(
            progress: progress,
            isSoftwareDimmingEnabled: true,
          );
          expect((restored - v).abs(), lessThan(1e-9));
        }
      },
    );

    testWidgets(
      'BrightnessSlider renders slider at progress 0.25 when value is 0% and dimming enabled',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BrightnessSlider(
                value: 0.0,
                min: -100.0,
                max: 100.0,
                isSoftwareDimmingEnabled: true,
                onChanged: (_) {},
              ),
            ),
          ),
        );

        final sliderFinder = find.byType(Slider);
        expect(sliderFinder, findsOneWidget);

        final sliderWidget = tester.widget<Slider>(sliderFinder);
        expect(sliderWidget.value, equals(0.25));
        expect(sliderWidget.min, equals(0.0));
        expect(sliderWidget.max, equals(1.0));

        expect(find.text('0%'), findsOneWidget);
        expect(find.byIcon(LucideIcons.sun), findsOneWidget);
      },
    );

    testWidgets('BrightnessSlider renders moon badge when value is below 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrightnessSlider(
              value: -40.0,
              min: -100.0,
              max: 100.0,
              isSoftwareDimmingEnabled: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final sliderWidget = tester.widget<Slider>(find.byType(Slider));
      // -40% -> ratio = 60/100 -> progress = 0.6 * 0.25 = 0.15
      expect((sliderWidget.value - 0.15).abs(), lessThan(1e-6));

      expect(find.text('-40%'), findsOneWidget);
      expect(
        find.byIcon(LucideIcons.moon),
        findsNWidgets(2),
      ); // Left icon + badge icon
    });

    testWidgets(
      'Magnetic snap snaps progress around 0.25 (±3% brightness) to 0.0',
      (tester) async {
        double changedValue = 999.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BrightnessSlider(
                value: 50.0,
                min: -100.0,
                max: 100.0,
                isSoftwareDimmingEnabled: true,
                onChanged: (val) => changedValue = val,
              ),
            ),
          ),
        );

        // Direct call to simulate slider onChanged near 0%
        // 0.25 is 0%
        // 0.26 is: (0.26 - 0.25) / 0.75 * 100 = 1.33% -> within ±3% -> snaps to 0.0
        // Trigger onChanged on the inner Slider widget
        final slider = tester.widget<Slider>(find.byType(Slider));
        slider.onChanged?.call(0.26);

        expect(changedValue, equals(0.0));

        // Test value outside snap threshold: 0.30 -> (0.05 / 0.75) * 100 = 6.67% -> not snapped
        slider.onChanged?.call(0.30);
        expect((changedValue - 6.666666666666667).abs(), lessThan(1e-4));
      },
    );

    testWidgets(
      'BrightnessSlider with default constructor args allows negative values down to -100',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BrightnessSlider(value: -50.0, onChanged: (_) {}),
            ),
          ),
        );

        final sliderWidget = tester.widget<Slider>(find.byType(Slider));
        // -50% -> ratio = 50/100 -> progress = 0.5 * 0.25 = 0.125
        expect((sliderWidget.value - 0.125).abs(), lessThan(1e-6));
        expect(find.text('-50%'), findsOneWidget);
        expect(find.byIcon(LucideIcons.moon), findsNWidgets(2));
      },
    );
  });
}
