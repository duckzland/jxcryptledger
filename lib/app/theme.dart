import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primary = Color(0xFF0088DB);

  static const inputBg = Color(0xFF111723);
  static const inputBorder = Color(0xFF242E3D);
  static const inputBorderDisabled = Color(0xFF1A202B);
  static const inputBorderFocused = Color(0xFF2C3748);
  static const inputErrorBorder = Color(0xFF992B2B);
  static const inputErrorText = Color(0xFFFF7A7A);

  static const tableHeaderBg = Colors.transparent;
  static const tableRowBg = Colors.transparent;

  static const treeConnector = Color(0xFE2C3544);

  static const treeBgNormal = Color(0xFF0d1421);
  static const treeFgNormal = text;

  static const treeBgInactive = Color(0xFF2E3A4E);
  static const treeFgInactive = textInactive;

  static const treeBgClosed = Color(0xFF2A2338);
  static const treeFgClosed = textHalfInactive;

  static const treeBgFinalized = Color(0xFF4D2A13);

  static const treeFgFinalized = textHalfInactive;

  static const treeBgCurrent = Color(0xFF1C3E2F);
  static const treeFgCurrent = text;

  static const error = Color(0xFFC62828);
  static const success = Color(0xFF43F436);
  static const warning = Color(0xFFD5A114);

  static const action = Color(0xFF43A047);
  static const loss = Color(0xFFE96A6A);
  static const profit = Color(0xFF00D695);

  static const text = Color(0xFFEEEEEE);
  static const textMuted = Color(0xB3BEBEBE);
  static const textInactive = Color(0x72DDDDDD);
  static const textHalfInactive = Color(0x99DDDDDD);

  static const appBarBg = Color(0xFF060A10);
  static const background = Color(0xFF0B111C);

  static const scrimBackground = Color(0xFF06070A);
  static const headerBg = Color(0xFF161C27);
  static const separator = Color(0xFF2C3544);
  static const panelBg = Color(0xFF0d1421);

  static const scrollbarBg = Color(0xFF2A354A);
  static const mutedBg = Color(0xFF292F3B);
  static const closedBg = Color(0xFF253442);
  static const finalizedBg = Color(0xFF253446);
  static const dialogBg = Color(0xFF0d1421);
  static const barrierBg = Color(0xD9000000);

  static const red = Color(0xFF641D1D);
  static const darkRed = Color(0xFF4A1212);
  static const green = Color(0xFF0F4F34);
  static const darkGreen = Color(0xFF0B3322);
  static const blue = Color(0xFF2C5EA9);
  static const lightBlue = Color(0xFF4C79AF);
  static const lightPurple = Color(0xFF796A97);
  static const lightOrange = Color(0xFFB4794C);
  static const orange = Color(0xFF915027);
  static const yellow = Color(0xFF927F32);
  static const teal = Color(0xFF1D7667);
  static const darkGrey = Color(0xFF1D1D1D);

  static const menuBackground = Color(0xFF1A2F4A);
  static const menuHeaderBg = Color(0xFF243659);
  static const menuBorder = Color(0xFF1A2F4A);

  static const cardBg = Color(0xFF1B2230);
  static const cardBorder = Color(0xFF2C3544);

  static const buttonBg = Color(0xFF253042);
  static const buttonFg = Color(0xFFE2E8F0);

  static const buttonBgDisabled = Color(0xFF0D131C);
  static const buttonFgDisabled = Color(0xFF4A5568);

  static const buttonBgActive = Color(0xFF0088DB);
  static const buttonFgActive = text;

  static const buttonBgPrimary = Color(0xFF0088DB);
  static const buttonFgPrimary = text;

  static const buttonBgProgress = Color(0xFF0088DB);
  static const buttonFgProgress = text;

  static const buttonBgError = Color(0xFF992B2B);
  static const buttonFgError = text;

  static const buttonBgAction = Color(0xFF00A86B);
  static const buttonFgAction = text;

  static const buttonBgWarning = Color(0xFFB88A00);
  static const buttonFgWarning = text;

  static const buttonBgMuted = Color(0xFF222D3D);
  static const buttonFgMuted = Color(0xFFBDD1DE);

  static const notifyBgSuccess = Color(0xFF1565C0);
  static const notifyFgSuccess = text;

  static const notifyBgError = Color(0xFFC62828);
  static const notifyFgError = text;

  static const notifyBgWarning = Color(0xFFEF6C00);
  static const notifyFgWarning = text;

  static const double tableHeadingRowHeight = 50;
  static const double tableDataRowMinHeight = 42;

  static const EdgeInsets menuPadding = EdgeInsets.symmetric(vertical: 4);
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(vertical: 12, horizontal: 12);

  static ThemeData get dark {
    final menuDecoration = MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(menuBackground),
        surfaceTintColor: WidgetStateProperty.all(menuBackground),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        padding: WidgetStateProperty.all(menuPadding),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: menuBorder, width: 1),
          ),
        ),
      ),
    );

    final inputDecoration = InputDecorationTheme(
      filled: true,
      fillColor: inputBg,

      labelStyle: const TextStyle(fontSize: 14, color: textMuted, fontFamily: 'Inter'),
      floatingLabelStyle: const TextStyle(fontSize: 13, color: text, fontFamily: 'Inter'),
      hintStyle: const TextStyle(color: textHalfInactive, fontFamily: 'Inter'),
      errorStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w400, color: inputErrorText),

      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: inputPadding,

      hoverColor: Colors.transparent,

      suffixIconConstraints: const BoxConstraints(maxHeight: 48),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: inputErrorBorder, width: 1),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: inputBorder, width: 1),
      ),

      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: inputBorderDisabled, width: 1),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: inputBorderFocused, width: 1),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      inputDecorationTheme: inputDecoration,
      menuTheme: menuDecoration,

      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w500),
        displayMedium: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w500),
        displaySmall: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w500),
        titleLarge: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w400),
        labelMedium: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w400),
        labelSmall: TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w400),

        headlineSmall: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w500, color: text),
        headlineMedium: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w500, color: text),
        headlineLarge: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w500, color: text),
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
        backgroundColor: appBarBg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: text, fontFamily: 'Inter'),
      ),

      dividerTheme: const DividerThemeData(color: separator, thickness: 1),

      cardTheme: CardThemeData(
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: dialogBg,
        surfaceTintColor: Colors.transparent,

        headerBackgroundColor: headerBg,
        headerForegroundColor: text,
        headerHeadlineStyle: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold),
        headerHelpStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: textInactive),

        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return textInactive;
          if (states.contains(WidgetState.selected)) return text;
          return text;
        }),

        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),

        todayBackgroundColor: WidgetStateProperty.all(inputBg),
        todayForegroundColor: WidgetStateProperty.all(primary),
        todayBorder: const BorderSide(color: primary, width: 1),

        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: textMuted,
          textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
        ),

        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: separator, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: buttonFg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
        headingRowColor: WidgetStateProperty.all(tableHeaderBg),
        headingTextStyle: const TextStyle(color: text, fontWeight: FontWeight.w500, fontSize: 14, fontFamily: 'Inter'),
        dataRowColor: WidgetStateProperty.all(tableRowBg),
        dataTextStyle: const TextStyle(color: text, fontSize: 14, fontFamily: 'Inter'),
        dividerThickness: 1,
        headingRowHeight: tableHeadingRowHeight,
        dataRowMinHeight: tableDataRowMinHeight,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return mutedBg;
          }
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return inputBg;
        }),
        checkColor: WidgetStateProperty.all(text),
        side: const BorderSide(color: inputBorderFocused, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),

      bottomSheetTheme: const BottomSheetThemeData(modalBarrierColor: barrierBg),

      dialogTheme: DialogThemeData(
        backgroundColor: dialogBg,
        surfaceTintColor: dialogBg,
        barrierColor: barrierBg,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: separator, width: 1),
        ),
        titleTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: text),
        contentTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400, color: text),
        iconColor: action,
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: menuDecoration.style,
        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: text),
        inputDecorationTheme: inputDecoration,
      ),
    );
  }
}
