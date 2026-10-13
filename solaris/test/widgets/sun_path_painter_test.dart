import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/widgets/sun_path_painter.dart';

Future<Uint8List> _render(double? progress) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  SunPathPainter(progress: progress).paint(canvas, const ui.Size(660, 400));
  final picture = recorder.endRecording();
  final image = await picture.toImage(660, 400);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Uint8List.fromList(data!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unknown position draws the arc without inventing a midday sun',
    () async {
      final unknown = await _render(null);
      final midday = await _render(0.5);
      final invalid = await _render(double.nan);

      expect(unknown.any((byte) => byte != 0), isTrue);
      expect(listEquals(unknown, midday), isFalse);
      expect(listEquals(unknown, invalid), isTrue);
    },
  );

  test(
    'identical progress renders identically and real movement changes the image',
    () async {
      final evening = await _render(0.8);
      final repeated = await _render(0.8);
      final midday = await _render(0.5);
      final night = await _render(-0.5);

      expect(listEquals(evening, repeated), isTrue);
      expect(listEquals(evening, midday), isFalse);
      expect(listEquals(night, midday), isFalse);
    },
  );
}
