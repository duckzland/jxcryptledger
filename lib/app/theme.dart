import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Color Mapping from Go/Fyne RGBA
  static const _background = Color(0xFF0D1421); // R: 13, G: 20, B: 33
  static const _primary = Color(0xFF007ACC); // R: 0, G: 122, B: 204
  static const _inputBg = Color(0xFF202023); // R: 32, G: 32, B: 35
  static const _panelBg = Color(0xFF323546); // R: 50, G: 53, B: 70
  static const _buttonBg = Color(0xFF28292E); // R: 40, G: 41, B: 46
  static const _error = Color(0xFFC62828); // R: 198, G: 40, B: 40
  static const _success = Color(0xFF43F436); // R: 67, G: 244, B: 54
  static const _headerBg = Color(0xFF1B1B1B); // R: 27, G: 27, B: 27
  static const _separator = Color(0xFF404040); // R: 64, G: 64, B: 64

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Font Configuration
      fontFamily:
          'Inter', // Ensure you have Inter-Bold and Inter-Medium in pubspec.yaml

      colorScheme: const ColorScheme.dark(
        surface: _background,
        primary: _primary,
        secondary: _primary,
        error: _error,
        onSurface: Colors.white,
        onPrimary: Colors.white,
      ),

      scaffoldBackgroundColor: _background,

      appBarTheme: const AppBarTheme(
        backgroundColor: _headerBg,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.bold,
          fontSize: 18, // theme.SizeNameSubHeadingText
        ),
      ),

      // Input Decoration (fyne theme.SizeNameInputRadius: 5)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _inputBg,
        // Shrink the label text (the static label)
        labelStyle: const TextStyle(
          fontSize: 16, // Reduced by 2px
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
        // Shrink the floating label (when the field is focused)
        floatingLabelStyle: const TextStyle(
          fontSize: 13, // Usually 2px smaller than the base label
          color: _primary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: const BorderSide(color: _separator),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Card Theme (Panel Style - SizePanelBorderRadius: 6)
      cardTheme: CardThemeData(
        color: _panelBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      // Button Theme (theme.SizeNameInputRadius: 5)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _buttonBg,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500, // Medium
            fontSize: 14, // theme.SizeNameText
          ),
        ),
      ),

      // Scrollbar (theme.SizeNameScrollBar: 4/12)
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        thickness: WidgetStateProperty.all(12),
        radius: const Radius.circular(3), // theme.SizeNameScrollBarRadius
        thumbColor: WidgetStateProperty.all(_panelBg),
      ),
    );
  }
}
