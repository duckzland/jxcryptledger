import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const seed = Colors.teal;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    );
  }
}
