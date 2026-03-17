import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF09111F);
  static const Color mist = Color(0xFFEAF7F4);
  static const Color cyan = Color(0xFF52E5D3);
  static const Color coral = Color(0xFFFF7A59);
  static const Color gold = Color(0xFFFFC857);
  static const Color slate = Color(0xFF14263C);
  static const Color panel = Color(0xCC102039);

  static ThemeData get darkTheme {
    const scheme = ColorScheme.dark(
      primary: cyan,
      secondary: coral,
      surface: slate,
      onPrimary: ink,
      onSecondary: ink,
      onSurface: mist,
      error: Color(0xFFFF6B7A),
    );

    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          color: mist,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          height: 0.95,
        ),
        headlineMedium: const TextStyle(
          color: mist,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleLarge: const TextStyle(
          color: mist,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleMedium: const TextStyle(
          color: mist,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        bodyLarge: const TextStyle(color: mist, height: 1.4),
        bodyMedium: const TextStyle(color: Color(0xFFB5C6D8), height: 1.45),
        labelLarge: const TextStyle(
          color: mist,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0x1FFFFFFF),
        side: const BorderSide(color: Color(0x33FFFFFF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        labelStyle: const TextStyle(color: mist, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xCC12233B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: cyan, width: 1.4),
        ),
        hintStyle: const TextStyle(color: Color(0x66EAF7F4)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: coral,
        foregroundColor: ink,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel,
        contentTextStyle: const TextStyle(color: mist),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
