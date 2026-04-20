import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primary = Color(0xFF007ACC);
  static const inputBg = Color(0xFF202023);

  static const error = Color(0xFFC62828);
  static const success = Color(0xFF43F436);
  static const warning = Color(0xFFD5A114);
  static const action = Color(0xFF43A047);
  static const loss = Color(0xFFFF6D6D);
  static const profit = Color(0xFF70E168);
  static const text = Colors.white;
  static const textMuted = Colors.white70;
  static const textInactive = Color(0x53FFFFFF);
  static const textHalfInactive = Color(0x72FFFFFF);

  static const background = Color(0xFF0D1421);
  static const scrimBackground = Color(0xFF06070A);
  static const menuHeaderBg = Color(0xFF1F3C6E);
  static const headerBg = Color(0xFF161C27);
  static const columnHeaderBg = Color(0xFF000000);
  static const rowHeaderBg = Color(0xFF0D1421);
  static const separator = Color(0xFF2C3544);
  static const panelBg = Color(0xFF1B2230);
  static const scrollbarBg = Color(0xFF2A354A);
  static const mutedBg = Color(0xFF292F3B);
  static const closedBg = Color(0xFF253442);
  static const finalizedBg = Color(0xFF253446);

  static const red = Color(0xFF852424);
  static const darkRed = Color(0xFF641919);
  static const green = Color(0xFF166A45);
  static const darkGreen = Color(0xFF0F462D);
  static const blue = Color(0xFF3C78DC);
  static const lightBlue = Color(0xFF64A0E6);
  static const lightPurple = Color(0xFFA08CC8);
  static const lightOrange = Color(0xFFF0A064);
  static const orange = Color(0xFFC36633);
  static const yellow = Color(0xFFC0A840);
  static const teal = Color(0xFF28AA8C);
  static const darkGrey = Color(0xFF282828);

  static const buttonBg = Color(0xFF28292E);
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

  static const buttonBgWarning = Color(0xFFD5A114);
  static const buttonFgWarning = Colors.white;

  static const double tableHeadingRowHeight = 50;
  static const double tableDataRowMinHeight = 42;

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',

      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Inter'),
        displayMedium: TextStyle(fontFamily: 'Inter'),
        displaySmall: TextStyle(fontFamily: 'Inter'),
        headlineLarge: TextStyle(fontFamily: 'Inter'),
        headlineMedium: TextStyle(fontFamily: 'Inter'),
        headlineSmall: TextStyle(fontFamily: 'Inter'),
        titleLarge: TextStyle(fontFamily: 'Inter'),
        titleMedium: TextStyle(fontFamily: 'Inter'),
        titleSmall: TextStyle(fontFamily: 'Inter'),
        bodyLarge: TextStyle(fontFamily: 'Inter'),
        bodyMedium: TextStyle(fontFamily: 'Inter'),
        bodySmall: TextStyle(fontFamily: 'Inter'),
        labelLarge: TextStyle(fontFamily: 'Inter'),
        labelMedium: TextStyle(fontFamily: 'Inter'),
        labelSmall: TextStyle(fontFamily: 'Inter'),
      ),

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
        titleTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: text, fontFamily: 'Inter'),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        labelStyle: const TextStyle(fontSize: 14, color: textInactive, fontFamily: 'Inter'),
        floatingLabelStyle: const TextStyle(fontSize: 13, color: textMuted, fontFamily: 'Inter'),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: separator)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: textInactive)),
        hintStyle: TextStyle(color: textHalfInactive, fontFamily: 'Inter'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: text, fontFamily: 'Inter'),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: 'Inter')),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(textStyle: const TextStyle(fontFamily: 'Inter')),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(false),
        thickness: WidgetStateProperty.all(4),
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
        decoration: BoxDecoration(color: buttonBg, borderRadius: BorderRadius.all(Radius.circular(4))),
        textStyle: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w400),
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(columnHeaderBg),
        headingTextStyle: const TextStyle(color: text, fontWeight: FontWeight.w500, fontSize: 14),
        dataRowColor: WidgetStateProperty.all(rowHeaderBg),
        dataTextStyle: const TextStyle(color: text, fontSize: 14),
        dividerThickness: 1,
        headingRowHeight: tableHeadingRowHeight,
        dataRowMinHeight: tableDataRowMinHeight,
      ),
    );
  }
}
