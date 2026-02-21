import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

class AppTheme {
  AppTheme._();

  static const background = Color(0xFF0D1421);
  static const primary = Color(0xFF007ACC);
  static const inputBg = Color(0xFF202023);
  static const panelBg = Color(0xFF323546);
  static const buttonBg = Color(0xFF28292E);
  static const error = Color(0xFFC62828);
  static const success = Color(0xFF43F436);
  static const headerBg = Color(0xFF1B1B1B);
  static const separator = Color(0xFF404040);
  static const text = Colors.white;
  static const textMuted = Colors.white70;

  static const buttonFg = Color(0xFFE0E0E0);

  static const buttonBgDisabled = Color(0xFF1A1B1F);
  static const buttonFgDisabled = Color(0xFF777777);

  static const buttonBgActive = Color(0xFF1976D2);
  static const buttonFgActive = Colors.white;

  static const buttonBgProgress = Color(0xFF1976D2);
  static const buttonFgProgress = Colors.white;

  static const buttonBgError = Color(0xFFD32F2F);
  static const buttonFgError = Colors.white;

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: const ColorScheme.dark(
        surface: background,
        primary: primary,
        secondary: primary,
        error: error,
        onSurface: text,
        onPrimary: text,
      ),

      scaffoldBackgroundColor: background,

      appBarTheme: const AppBarTheme(
        backgroundColor: headerBg,
        foregroundColor: text,
        elevation: 0,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: text),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,

        labelStyle: const TextStyle(fontSize: 16, color: textMuted),

        floatingLabelStyle: const TextStyle(fontSize: 13, color: text),

        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),

        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: primary)),

        hintStyle: TextStyle(color: textMuted),
      ),

      cardTheme: CardThemeData(
        color: panelBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: text),
        ),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        thickness: WidgetStateProperty.all(12),
        radius: const Radius.circular(3),
        thumbColor: WidgetStateProperty.all(panelBg),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: buttonBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        contentTextStyle: const TextStyle(color: text, fontWeight: FontWeight.w500),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(color: Color(0xFF323546), borderRadius: BorderRadius.all(Radius.circular(4))),
        textStyle: TextStyle(color: Color(0xFFE0E0E0), fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class AppPlutoTheme {
  static PlutoGridConfiguration get config {
    return PlutoGridConfiguration(
      style: PlutoGridStyleConfig(
        gridBackgroundColor: AppTheme.headerBg,
        rowColor: AppTheme.separator,

        // Darker border
        gridBorderColor: AppTheme.separator,

        // Darker icons
        iconColor: AppTheme.separator,

        cellTextStyle: const TextStyle(color: AppTheme.text, fontSize: 14),

        columnTextStyle: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600, fontSize: 13),

        columnHeight: 38,
        rowHeight: 32,

        // activatedColor: AppTheme.panelBg,
        // activatedBorderColor: AppTheme.primary,
        activatedBorderColor: Colors.transparent,
        activatedColor: Colors.transparent,

        menuBackgroundColor: AppTheme.panelBg,

        borderColor: Colors.transparent,
        enableCellBorderVertical: false,
        enableColumnBorderVertical: false,
      ),
      columnSize: const PlutoGridColumnSizeConfig(autoSizeMode: PlutoAutoSizeMode.scale),
    );
  }
}
