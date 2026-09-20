import 'package:flutter/material.dart';

/// Extracted from the official Tutoria logo (logo.png).
class TutoriaColors {
  static const blue = Color(0xFF0235CC);
  static const gold = Color(0xFFFEBF00);
  static const orange = Color(0xFFBC5900);
}

ThemeData buildTutoriaTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: TutoriaColors.blue,
    brightness: Brightness.light,
  ).copyWith(
    primary: TutoriaColors.blue,
    onPrimary: Colors.white,
    secondary: TutoriaColors.gold,
    onSecondary: Colors.black,
    tertiary: TutoriaColors.orange,
    onTertiary: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: TutoriaColors.blue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TutoriaColors.blue, width: 2),
      ),
      filled: true,
      fillColor: colorScheme.surfaceContainerLowest,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TutoriaColors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: TutoriaColors.blue),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: TutoriaColors.gold.withValues(alpha: 0.18),
      labelStyle: const TextStyle(color: TutoriaColors.orange, fontWeight: FontWeight.w600),
      side: BorderSide.none,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
  );
}
