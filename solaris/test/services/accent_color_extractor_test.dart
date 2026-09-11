import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/accent_color_extractor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => Directory.systemTemp.path,
        );
  });

  group('AccentColorExtractor Utility & Parsing Tests', () {
    test('colorToHex converts RGB correctly to uppercase hex', () {
      expect(
        AccentColorExtractor.colorToHex(const Color(0xFF6366F1)),
        '#6366F1',
      );
      expect(
        AccentColorExtractor.colorToHex(const Color(0xFF000000)),
        '#000000',
      );
      expect(
        AccentColorExtractor.colorToHex(const Color(0xFFFFFFFF)),
        '#FFFFFF',
      );
      expect(
        AccentColorExtractor.colorToHex(const Color(0xFFE2E8F0)),
        '#E2E8F0',
      );
      expect(
        AccentColorExtractor.colorToHex(const Color(0xFF94A3B8)),
        '#94A3B8',
      );
    });

    test('hexToColor parses valid 6 and 8 character hex strings', () {
      expect(
        AccentColorExtractor.hexToColor('#6366F1').toARGB32(),
        const Color(0xFF6366F1).toARGB32(),
      );
      expect(
        AccentColorExtractor.hexToColor('6366F1').toARGB32(),
        const Color(0xFF6366F1).toARGB32(),
      );
      expect(
        AccentColorExtractor.hexToColor('#FF6366F1').toARGB32(),
        const Color(0xFF6366F1).toARGB32(),
      );
    });

    test('hexToColor returns fallback on invalid hex strings', () {
      const fallback = Color(0xFFFF0000);
      expect(AccentColorExtractor.hexToColor('', fallback), fallback);
      expect(AccentColorExtractor.hexToColor('invalid', fallback), fallback);
      expect(AccentColorExtractor.hexToColor('#12345', fallback), fallback);
    });

    test(
      'isAchromatic correctly distinguishes monochrome vs chromatic colors',
      () {
        // Pure monochrome & neutral slate tones
        expect(
          AccentColorExtractor.isAchromatic(const Color(0xFF000000)),
          isTrue,
        );
        expect(
          AccentColorExtractor.isAchromatic(const Color(0xFFFFFFFF)),
          isTrue,
        );
        expect(
          AccentColorExtractor.isAchromatic(const Color(0xFF888888)),
          isTrue,
        );
        expect(
          AccentColorExtractor.isAchromatic(AccentColorExtractor.neutralLight),
          isTrue,
        ); // Slate 200
        expect(
          AccentColorExtractor.isAchromatic(AccentColorExtractor.neutralDark),
          isTrue,
        ); // Slate 400

        // Chromatic colors
        expect(
          AccentColorExtractor.isAchromatic(const Color(0xFF6366F1)),
          isFalse,
        ); // Indigo
        expect(
          AccentColorExtractor.isAchromatic(const Color(0xFFFF0000)),
          isFalse,
        ); // Red
        expect(
          AccentColorExtractor.isAchromatic(const Color(0xFF00FF00)),
          isFalse,
        ); // Green
        expect(
          AccentColorExtractor.isAchromatic(const Color(0xFF0000FF)),
          isFalse,
        ); // Blue
        expect(
          AccentColorExtractor.isAchromatic(const Color(0xFF38BDF8)),
          isFalse,
        ); // Sky
      },
    );
  });

  group('AccentColorExtractor Image Extraction Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'solaris_extractor_test_',
      );
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    Future<String> createPngFile(String filename, Color color) async {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 32, 32),
        Paint()..color = color,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(32, 32);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(byteData!.buffer.asUint8List());
      return file.path;
    }

    test(
      'extractAccentColor returns fallback for non-existent or empty path',
      () async {
        const fallback = Color(0xFF123456);
        expect(
          await AccentColorExtractor.extractAccentColor('', fallback: fallback),
          fallback,
        );
        expect(
          await AccentColorExtractor.extractAccentColor(
            'C:\\non_existent_file.png',
            fallback: fallback,
          ),
          fallback,
        );
      },
    );

    testWidgets(
      'extractAccentColor extracts vibrant chromatic color for vibrant image',
      (tester) async {
        await tester.runAsync(() async {
          final path = await createPngFile(
            'vibrant_blue.png',
            const Color(0xFF0066FF),
          );
          final color = await AccentColorExtractor.extractAccentColor(path);

          expect(AccentColorExtractor.isAchromatic(color), isFalse);
          final hsl = HSLColor.fromColor(color);
          expect(hsl.saturation, greaterThanOrEqualTo(0.15));
          expect(hsl.hue, inInclusiveRange(200, 240)); // Blue range
        });
      },
    );

    testWidgets(
      'extractAccentColor extracts neutralLight for light monochrome/gray image',
      (tester) async {
        await tester.runAsync(() async {
          final path = await createPngFile(
            'light_gray.png',
            const Color(0xFFD4D4D8),
          );
          final color = await AccentColorExtractor.extractAccentColor(path);

          expect(AccentColorExtractor.isAchromatic(color), isTrue);
          expect(
            color.toARGB32(),
            AccentColorExtractor.neutralLight.toARGB32(),
          );
        });
      },
    );

    testWidgets(
      'extractAccentColor extracts neutralDark for dark monochrome/black image',
      (tester) async {
        await tester.runAsync(() async {
          final path = await createPngFile(
            'pure_black.png',
            const Color(0xFF000000),
          );
          final color = await AccentColorExtractor.extractAccentColor(path);

          expect(AccentColorExtractor.isAchromatic(color), isTrue);
          expect(color.toARGB32(), AccentColorExtractor.neutralDark.toARGB32());
        });
      },
    );

    testWidgets(
      'extractAccentHex returns uppercase hex representation of extracted color',
      (tester) async {
        await tester.runAsync(() async {
          final path = await createPngFile(
            'pure_black_hex.png',
            const Color(0xFF000000),
          );
          final hex = await AccentColorExtractor.extractAccentHex(path);

          expect(hex, '#94A3B8');
        });
      },
    );
  });
}
