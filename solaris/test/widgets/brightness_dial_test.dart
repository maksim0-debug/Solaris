import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/widgets/brightness_dial.dart';

class _RecordingCanvas extends Fake implements Canvas {
  final List<
    ({
      Rect rect,
      double startAngle,
      double sweepAngle,
      bool useCenter,
      Paint paint,
    })
  >
  arcs = [];
  final List<({Offset c, double radius, Paint paint})> circles = [];

  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) {
    arcs.add((
      rect: rect,
      startAngle: startAngle,
      sweepAngle: sweepAngle,
      useCenter: useCenter,
      paint: paint,
    ));
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    circles.add((c: c, radius: radius, paint: paint));
  }
}

void main() {
  group('BrightnessDialPainter Tests', () {
    test(
      'Negative brightness (-0.38, -1.0) clamps to 0: no inverted arc, glow anchored at zero position',
      () {
        final painter = BrightnessDialPainter(brightness: -0.38);
        final recordingCanvas = _RecordingCanvas();
        final size = const Size(240, 240);

        painter.paint(recordingCanvas, size);

        // Only 1 arc should be drawn: the background track
        expect(recordingCanvas.arcs.length, equals(1));
        expect(recordingCanvas.arcs.first.sweepAngle, closeTo(pi * 1.6, 1e-5));

        // Glow circle anchored at the zero mark (pi * 0.7)
        expect(recordingCanvas.circles.length, equals(1));
        final center = const Offset(120, 120);
        const radius = 120.0;
        const zeroAngle = pi * 0.7;
        final expectedPos = Offset(
          center.dx + radius * cos(zeroAngle),
          center.dy + radius * sin(zeroAngle),
        );
        expect(
          recordingCanvas.circles.first.c.dx,
          closeTo(expectedPos.dx, 1e-4),
        );
        expect(
          recordingCanvas.circles.first.c.dy,
          closeTo(expectedPos.dy, 1e-4),
        );
        expect(recordingCanvas.circles.first.radius, equals(10));
      },
    );

    test(
      'Zero brightness (0.0) only paints background arc and glow anchored at zero position',
      () {
        final painter = BrightnessDialPainter(brightness: 0.0);
        final recordingCanvas = _RecordingCanvas();
        final size = const Size(240, 240);

        painter.paint(recordingCanvas, size);

        expect(recordingCanvas.arcs.length, equals(1));
        expect(recordingCanvas.arcs.first.sweepAngle, closeTo(pi * 1.6, 1e-5));

        // Glow circle anchored at the zero mark (pi * 0.7)
        expect(recordingCanvas.circles.length, equals(1));
        final center = const Offset(120, 120);
        const radius = 120.0;
        const zeroAngle = pi * 0.7;
        final expectedPos = Offset(
          center.dx + radius * cos(zeroAngle),
          center.dy + radius * sin(zeroAngle),
        );
        expect(
          recordingCanvas.circles.first.c.dx,
          closeTo(expectedPos.dx, 1e-4),
        );
        expect(
          recordingCanvas.circles.first.c.dy,
          closeTo(expectedPos.dy, 1e-4),
        );
      },
    );

    test(
      'Positive brightness (0.48) paints background arc, progress arc, and glow at tip',
      () {
        final painter = BrightnessDialPainter(brightness: 0.48);
        final recordingCanvas = _RecordingCanvas();
        final size = const Size(240, 240);

        painter.paint(recordingCanvas, size);

        // Background arc + Progress arc
        expect(recordingCanvas.arcs.length, equals(2));
        expect(recordingCanvas.arcs[0].sweepAngle, closeTo(pi * 1.6, 1e-5));
        expect(
          recordingCanvas.arcs[1].sweepAngle,
          closeTo(pi * 1.6 * 0.48, 1e-5),
        );

        // Glow circle at progress end
        expect(recordingCanvas.circles.length, equals(1));
        final center = const Offset(120, 120);
        const radius = 120.0;
        final expectedAngle = pi * 0.7 + pi * 1.6 * 0.48;
        final expectedPos = Offset(
          center.dx + radius * cos(expectedAngle),
          center.dy + radius * sin(expectedAngle),
        );
        expect(
          recordingCanvas.circles.first.c.dx,
          closeTo(expectedPos.dx, 1e-4),
        );
        expect(
          recordingCanvas.circles.first.c.dy,
          closeTo(expectedPos.dy, 1e-4),
        );
        expect(recordingCanvas.circles.first.radius, equals(10));
      },
    );

    test('Values exceeding 1.0 (e.g. 1.5) clamp to 1.0 maximum', () {
      final painter = BrightnessDialPainter(brightness: 1.5);
      final recordingCanvas = _RecordingCanvas();
      final size = const Size(240, 240);

      painter.paint(recordingCanvas, size);

      expect(recordingCanvas.arcs.length, equals(2));
      expect(recordingCanvas.arcs[1].sweepAngle, closeTo(pi * 1.6, 1e-5));
    });

    test(
      'shouldRepaint optimizes repaints when both old and new brightness are <= 0',
      () {
        final painterMinus38 = BrightnessDialPainter(brightness: -0.38);
        final painterMinus100 = BrightnessDialPainter(brightness: -1.0);
        final painterZero = BrightnessDialPainter(brightness: 0.0);
        final painter50 = BrightnessDialPainter(brightness: 0.5);
        final painter60 = BrightnessDialPainter(brightness: 0.6);

        // Both <= 0: visually identical (clamped to 0.0), no repaint needed
        expect(painterMinus100.shouldRepaint(painterMinus38), isFalse);
        expect(painterZero.shouldRepaint(painterMinus38), isFalse);

        // Transition across boundary: repaints
        expect(painter50.shouldRepaint(painterMinus38), isTrue);
        expect(painterMinus38.shouldRepaint(painter50), isTrue);

        // Different positive values: repaints
        expect(painter60.shouldRepaint(painter50), isTrue);

        // Identical positive value: no repaint
        final painter50Copy = BrightnessDialPainter(brightness: 0.5);
        expect(painter50Copy.shouldRepaint(painter50), isFalse);
      },
    );

    testWidgets(
      'BrightnessDialPainter renders cleanly in widget tree without error',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(
                    painter: BrightnessDialPainter(brightness: -0.38),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
      },
    );
  });
}
