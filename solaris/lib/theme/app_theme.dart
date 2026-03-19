import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFF020617);
  static const Color surface = Color(0xFF0F172A);
  static const Color accent = Color(0xFFFDBA74);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      surface: surface,
      onSurface: textPrimary,
    ),
    textTheme: GoogleFonts.outfitTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: GoogleFonts.outfit(color: textPrimary, fontSize: 16),
      bodyMedium: GoogleFonts.outfit(color: textMuted, fontSize: 14),
    ),
  );
}
