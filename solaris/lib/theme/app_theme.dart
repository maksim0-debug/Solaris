import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF020617);
  static const Color surface = Color(0xFF0F172A);
  static const Color accent = Color(0xFFFDBA74);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);

  static const String _fontFamily = 'Outfit';

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
      titleTextStyle: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      subtitleTextStyle: const TextStyle(fontFamily: _fontFamily, color: textMuted, fontSize: 14),
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
    textTheme: TextTheme(
      displayLarge: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
      displaySmall: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
      headlineLarge: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
      headlineMedium: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      headlineSmall: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      titleLarge: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: const TextStyle(fontFamily: _fontFamily, color: textMuted, fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 16),
      bodyMedium: TextStyle(fontFamily: _fontFamily, color: textPrimary.withOpacity(0.9), fontSize: 14),
      bodySmall: TextStyle(fontFamily: _fontFamily, color: textPrimary.withOpacity(0.7), fontSize: 12),
      labelLarge: const TextStyle(fontFamily: _fontFamily, color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: const TextStyle(fontFamily: _fontFamily, color: textMuted, fontSize: 12),
      labelSmall: const TextStyle(fontFamily: _fontFamily, color: textMuted, fontSize: 10),
    ),
  );
}

