import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// High-performance service for extracting vibrant dominant accent colors
/// from application icons for glowing UI aesthetics in Solaris.
class AccentColorExtractor {
  static const String defaultHex = '#6366F1';
  static const Color defaultColor = Color(0xFF6366F1);
  static const Color neutralLight = Color(0xFFE2E8F0);
  static const Color neutralDark = Color(0xFF94A3B8);

  AccentColorExtractor._();

  /// Determines whether a color is monochromatic/achromatic.
  /// Achromatic colors have low chroma (spread between max and min RGB components <= 45 out of 255).
  static bool isAchromatic(Color color) {
    final argb = color.toARGB32();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final maxComponent = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final minComponent = r < g ? (r < b ? r : b) : (g < b ? g : b);
    return (maxComponent - minComponent) <= 45;
  }

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
      // Downsample to 32x32 and limit color count to 16 for ultra-fast, zero-overhead execution.
      // Pass filters: const [] so PaletteGenerator does not discard black, white, or grayscale pixels.
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(32, 32),
        maximumColorCount: 16,
        timeout: const Duration(milliseconds: 300),
        filters: const [],
      );

      final selectedColor = _selectBestAccentColor(palette);
      return selectedColor ?? fallback;
    } catch (e) {
      debugPrint(
        'AccentColorExtractor failed to extract color from $imagePath: $e',
      );
      return fallback;
    }
  }

  /// Intelligent chromatic & achromatic scoring: finds the most vibrant, vivid color from the palette.
  /// If the icon is monochromatic (no color passes saturation >= 0.15), it returns a neutral silver
  /// or muted slate tone instead of an artificial vibrant fallback.
  static Color? _selectBestAccentColor(PaletteGenerator palette) {
    // 1. Score all visible chromatic palette colors by (Saturation^2 * LightnessBalance * Population).
    // This prioritizes the dominant visual mass of the icon (e.g. blue body in Antigravity)
    // while ensuring vivid colors beat low-saturation pastel backgrounds.
    Color? bestChromaticColor;
    double bestScore = -1.0;

    for (final paletteColor in palette.paletteColors) {
      final color = paletteColor.color;
      final alpha = (color.toARGB32() >> 24) & 0xFF;
      if (alpha < 30) continue; // Ignore transparent pixels

      final hsl = HSLColor.fromColor(color);

      // Discard pure black, pure white, and near-extremes
      if (hsl.lightness < 0.10 || hsl.lightness > 0.92) continue;

      // Only consider chromatic colors (saturation >= 18%)
      if (hsl.saturation < 0.18) continue;

      // Score = (Saturation^2) * (1 - |Lightness - 0.5|) * (Population + 1)
      final lightnessBalance = 1.0 - (hsl.lightness - 0.5).abs();
      final score =
          (hsl.saturation * hsl.saturation) *
          lightnessBalance *
          (paletteColor.population + 1);

      if (score > bestScore) {
        bestScore = score;
        bestChromaticColor = color;
      }
    }

    if (bestChromaticColor != null) {
      return bestChromaticColor;
    }

    // 2. Direct candidate targets from PaletteGenerator (strict vibrant targets as fallback)
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

    // 3. Fallback to dominant or first palette color if it has adequate saturation and is chromatic
    final dominant = palette.dominantColor?.color ?? palette.colors.firstOrNull;
    if (dominant != null &&
        !isAchromatic(dominant) &&
        HSLColor.fromColor(dominant).saturation >= 0.15) {
      return dominant;
    }

    // 4. Achromatic / Monochrome handling (e.g. silver/white or black icons):
    // Rather than returning null (which triggers an artificial vibrant indigo fallback),
    // determine whether the icon has visible light/silver elements or is a dark/black silhouette.
    final visibleColors = palette.paletteColors.where((p) {
      final alpha = (p.color.toARGB32() >> 24) & 0xFF;
      return alpha > 20;
    }).toList();

    if (visibleColors.isNotEmpty) {
      final hasLightElement = visibleColors.any((p) {
        final hsl = HSLColor.fromColor(p.color);
        return hsl.lightness >= 0.25;
      });

      return hasLightElement ? neutralLight : neutralDark;
    }

    if (dominant != null) {
      final hsl = HSLColor.fromColor(dominant);
      return hsl.lightness >= 0.25 ? neutralLight : neutralDark;
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
