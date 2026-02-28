import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // static const background = Color(0xFF0D1421);
  static const primary = Color(0xFF007ACC);
  static const inputBg = Color(0xFF202023);
  //static const panelBg = Color(0xFF323546);
  static const buttonBg = Color(0xFF28292E);
  static const error = Color(0xFFC62828);
  static const success = Color(0xFF43F436);
  static const warning = Color.fromARGB(255, 213, 161, 20);
  static const action = Color(0xFF43A047);
  static const loss = Color.fromARGB(255, 245, 50, 50);
  static const profit = Color.fromARGB(255, 62, 220, 51);
  // static const headerBg = Color(0xFF1B1B1B);
  // static const separator = Color(0xFF404040);
  static const text = Colors.white;
  static const textMuted = Colors.white70;
  // static const columnHeaderBg = Color(0xFF000000);
  // static const rowHeaderBg = Color(0xFF000000);

  static const background = Color(0xFF0D1421);
  static const scrimBackground = Color.fromARGB(255, 6, 7, 10);
  static const headerBg = Color(0xFF161C27);
  static const columnHeaderBg = Color(0xFF000000);
  static const rowHeaderBg = Color(0xFF0D1421);
  static const separator = Color.fromARGB(255, 44, 53, 68);
  static const panelBg = Color(0xFF1B2230);
  static const scrollbarBg = Color.fromARGB(255, 42, 53, 74);
  static const mutedBg = Color.fromARGB(255, 31, 36, 46);
  static const closedBg = Color.fromARGB(255, 36, 49, 61);

  static const buttonFg = Color(0xFFE0E0E0);

  static const buttonBgDisabled = Color(0xFF1A1B1F);
  static const buttonFgDisabled = Color(0xFF777777);

  static const buttonBgActive = Color(0xFF1976D2);
  static const buttonFgActive = Colors.white;

  static const buttonBgPrimary = Color(0xFF1976D2);
  static const buttonFgPrimary = Colors.white;

  static const buttonBgProgress = Color(0xFF1976D2);
  static const buttonFgProgress = Colors.white;

  static const buttonBgError = Color(0xFFD32F2F);
  static const buttonFgError = Colors.white;

  static const buttonBgAction = Color(0xFF43A047);
  static const buttonFgAction = Colors.white;

  static const buttonBgWarning = Color.fromARGB(255, 213, 161, 20);
  static const buttonFgWarning = Colors.white;

  static const double tableHeadingRowHeight = 50;
  static const double tableDataRowMinHeight = 42;

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
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: separator)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: primary)),
        hintStyle: TextStyle(color: textMuted),
      ),

      dividerTheme: const DividerThemeData(color: AppTheme.separator, thickness: 1),

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
        thumbColor: WidgetStateProperty.all(scrollbarBg),
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

      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppTheme.columnHeaderBg),
        headingTextStyle: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w500, fontSize: 14),
        dataRowColor: WidgetStateProperty.all(AppTheme.rowHeaderBg),
        dataTextStyle: const TextStyle(color: AppTheme.text, fontSize: 14),
        dividerThickness: 1,
        headingRowHeight: AppTheme.tableHeadingRowHeight,
        dataRowMinHeight: AppTheme.tableDataRowMinHeight,
      ),
    );
  }
}
