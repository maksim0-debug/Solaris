import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// High-performance service for extracting vibrant dominant accent colors
/// from application icons for glowing UI aesthetics in Solaris.
class AccentColorExtractor {
  static const String defaultHex = '#6366F1';
  static const Color defaultColor = Color(0xFF6366F1);

  AccentColorExtractor._();

  /// Extracts the most vibrant, chromatic accent color from an image file as a 6-character HEX string (e.g. `#6366F1`).
  static Future<String> extractAccentHex(
    String imagePath, {
    String fallbackHex = defaultHex,
  }) async {
    final color = await extractAccentColor(
      imagePath,
      fallback: hexToColor(fallbackHex),
    );
    return colorToHex(color);
  }

  /// Extracts the most vibrant, chromatic accent color from an image file as a Flutter [Color].
  static Future<Color> extractAccentColor(
    String imagePath, {
    Color fallback = defaultColor,
  }) async {
    if (imagePath.isEmpty) return fallback;

    final file = File(imagePath);
    if (!await file.exists()) return fallback;

    try {
      final imageProvider = FileImage(file);
      // Downsample to 32x32 and limit color count to 16 for ultra-fast, zero-overhead execution
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(32, 32),
        maximumColorCount: 16,
        timeout: const Duration(milliseconds: 300),
      );

      final selectedColor = _selectBestVibrantColor(palette);
      return selectedColor ?? fallback;
    } catch (e) {
      debugPrint(
        'AccentColorExtractor failed to extract color from $imagePath: $e',
      );
      return fallback;
    }
  }

  /// Intelligent chromatic scoring: finds the most vibrant, vivid color from the palette,
  /// filtering out near-black, near-white, and muddy greys.
  static Color? _selectBestVibrantColor(PaletteGenerator palette) {
    // 1. Direct candidate targets from PaletteGenerator (strict vibrant targets only)
    final candidates = <Color?>[
      palette.vibrantColor?.color,
      palette.lightVibrantColor?.color,
      palette.darkVibrantColor?.color,
    ].whereType<Color>().toList();

    for (final c in candidates) {
      if (_isGoodVibrantCandidate(c)) {
        return c;
      }
    }

    // 2. Score all detected palette colors to find the highest chromatic contrast
    Color? bestColor;
    double bestScore = -1.0;

    for (final paletteColor in palette.paletteColors) {
      final color = paletteColor.color;
      final hsl = HSLColor.fromColor(color);

      // Discard pure black/white/transparent extremes
      if (hsl.lightness < 0.10 || hsl.lightness > 0.92) continue;

      // Score = Saturation * (1 - |Lightness - 0.5|) * Population
      final lightnessBalance = 1.0 - (hsl.lightness - 0.5).abs();
      final score =
          hsl.saturation * lightnessBalance * (paletteColor.population + 1);

      if (score > bestScore && hsl.saturation >= 0.15) {
        bestScore = score;
        bestColor = color;
      }
    }

    if (bestColor != null) {
      return bestColor;
    }

    // 3. Fallback to dominant or first palette color if it has adequate saturation;
    // otherwise return null to trigger the vibrant default glow fallback.
    final dominant = palette.dominantColor?.color ?? palette.colors.firstOrNull;
    if (dominant != null && HSLColor.fromColor(dominant).saturation >= 0.15) {
      return dominant;
    }

    return null;
  }

  /// Determines whether a color has adequate saturation and balanced lightness for a neon glow.
  static bool _isGoodVibrantCandidate(Color color) {
    final hsl = HSLColor.fromColor(color);
    // Saturation >= 25% and Lightness between 15% and 85%
    return hsl.saturation >= 0.25 &&
        hsl.lightness >= 0.15 &&
        hsl.lightness <= 0.85;
  }

  /// Converts a Flutter [Color] into a standard uppercase 6-char hex string `#RRGGBB`.
  static String colorToHex(Color color) {
    final int rgb = (color.toARGB32() & 0x00FFFFFF);
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Parses a HEX color string into a Flutter [Color], with a fallback on error.
  static Color hexToColor(String hex, [Color fallback = defaultColor]) {
    try {
      var clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }
}
