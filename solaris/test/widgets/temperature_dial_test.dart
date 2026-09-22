import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/widgets/temperature_dial.dart';

void main() {
  group('TemperatureDialPainter Tests', () {
    testWidgets('Renders properly with standard 2-color gradient', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: CustomPaint(
                  painter: TemperatureDialPainter(progress: 0.5),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
      'Renders properly with extended 3-color gradient at candle temperature',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: TemperatureDialPainter(progress: 0.9),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      'Renders safely without throwing when progress is out-of-bounds (<0 or >1)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: TemperatureDialPainter(progress: -0.5),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(CustomPaint), findsWidgets);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: TemperatureDialPainter(progress: 1.5),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    test('shouldRepaint detects progress changes accurately', () {
      final painter1 = TemperatureDialPainter(progress: 0.5);
      final painter2 = TemperatureDialPainter(progress: 0.5);
      final painter3 = TemperatureDialPainter(progress: 0.8);

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter1.shouldRepaint(painter3), isTrue);
    });
  });
}
