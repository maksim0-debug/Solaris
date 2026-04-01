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
    canvasColor: background,
    cardColor: surface,
    dividerColor: Colors.white.withOpacity(0.1),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    listTileTheme: ListTileThemeData(
      textColor: textPrimary,
      iconColor: accent,
      selectedTileColor: accent.withOpacity(0.1),
      selectedColor: accent,
      titleTextStyle: GoogleFonts.outfit(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      subtitleTextStyle: GoogleFonts.outfit(color: textMuted, fontSize: 14),
    ),
    iconTheme: const IconThemeData(color: textPrimary),
    primaryIconTheme: const IconThemeData(color: textPrimary),
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: surface,
      onSurface: textPrimary,
      onPrimary: Colors.black,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.outfit(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.outfit(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.outfit(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.outfit(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      headlineSmall: GoogleFonts.outfit(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.outfit(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.outfit(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.outfit(color: textMuted, fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.outfit(color: textPrimary, fontSize: 16),
      bodyMedium: GoogleFonts.outfit(color: textPrimary.withOpacity(0.9), fontSize: 14),
      bodySmall: GoogleFonts.outfit(color: textPrimary.withOpacity(0.7), fontSize: 12),
      labelLarge: GoogleFonts.outfit(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: GoogleFonts.outfit(color: textMuted, fontSize: 12),
      labelSmall: GoogleFonts.outfit(color: textMuted, fontSize: 10),
    ),
  );
}
