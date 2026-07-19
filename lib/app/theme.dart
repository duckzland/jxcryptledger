import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primary = Color(0xFF0088DB);

  static const inputBg = Color(0xFF111723);
  static const inputBorder = Color(0xFF242E3D);
  static const inputBorderDisabled = Color(0xFF1A202B);
  static const inputBorderFocused = Color(0xFF353F52);
  static const inputErrorBorder = Color(0xFF992B2B);
  static const inputErrorText = Color.fromARGB(255, 227, 227, 227);

  static const tableHeaderBg = Colors.transparent;
  static const tableRowBg = Colors.transparent;

  static const treeConnector = Color(0xFF2C3748);

  static const treeBgNormal = Color(0xFF161D30);
  static const treeFgNormal = text;

  static const treeBgInactive = Color(0xFF2C3A50);
  static const treeFgInactive = textInactive;

  static const treeBgClosed = Color(0xFF202A3D);
  static const treeFgClosed = textHalfInactive;

  static const treeBgFinalized = Color(0xFF2A2F46);
  static const treeFgFinalized = textHalfInactive;

  static const treeBgCurrent = Color(0xFF1C2F4A);
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
  static const background = Color(0xFF06070A);

  static const scrimBackground = Color(0xFF06070A);
  static const headerBg = Color(0xFF161C27);
  static const separator = Color(0xFF2C3544);
  static const panelBg = Color(0xFF0D1421);

  static const scrollbarBg = Color(0xFF2A354A);
  static const mutedBg = Color(0xFF292F3B);
  static const closedBg = Color(0xFF253442);
  static const finalizedBg = Color(0xFF253446);
  static const dialogBg = Color(0xFF0d1421);
  static const barrierBg = Color(0xD9000000);
  static const divider = Color(0xFF242E3D);

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

  static const tooltipBg = Color(0xFF1A2F4A);
  static const tooltipFg = Color(0xFFEEEEEE);

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

  static const text600 = TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w600);
  static const text500 = TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w500);
  static const text400 = TextStyle(fontFamily: 'Inter', color: text, fontWeight: FontWeight.w400);

  static const borderRadius = BorderRadius.all(Radius.circular(6));

  static ThemeData get dark {
    final menuDecoration = MenuThemeData(
      style: MenuStyle(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        backgroundColor: WidgetStateProperty.all(menuBackground),
        surfaceTintColor: WidgetStateProperty.all(menuBackground),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        padding: WidgetStateProperty.all(menuPadding),
        shape: WidgetStateProperty.all(
          const RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: menuBorder, width: 1),
          ),
        ),
      ),
    );

    final inputDecoration = InputDecorationTheme(
      filled: true,
      fillColor: inputBg,

      labelStyle: text400.copyWith(fontSize: 14, color: textMuted),
      floatingLabelStyle: text400.copyWith(fontSize: 13, color: text),
      hintStyle: text400.copyWith(color: textHalfInactive),
      errorStyle: text400.copyWith(fontSize: 12, color: inputErrorText),

      border: const OutlineInputBorder(borderRadius: borderRadius),
      contentPadding: inputPadding,

      hoverColor: Colors.transparent,

      suffixIconConstraints: const BoxConstraints(maxHeight: 48),

      errorBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: inputErrorBorder, width: 1),
      ),

      enabledBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: inputBorder, width: 1),
      ),

      disabledBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: inputBorderDisabled, width: 1),
      ),

      focusedBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: inputBorderFocused, width: 1),
      ),
    );

    final textButton = TextButton.styleFrom(
      textStyle: text400,
    ).copyWith(overlayColor: WidgetStateProperty.all(Colors.transparent), mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click));

    final outlinedButton = OutlinedButton.styleFrom(
      textStyle: text400,
    ).copyWith(mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click));

    final elevatedButton = ElevatedButton.styleFrom(
      backgroundColor: buttonBg,
      foregroundColor: buttonFg,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: borderRadius),
      textStyle: text500.copyWith(fontSize: 14),
    ).copyWith(mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      inputDecorationTheme: inputDecoration,
      menuTheme: menuDecoration,

      textTheme: TextTheme(
        displayLarge: text500,
        displayMedium: text500,
        displaySmall: text500,
        titleLarge: text500,
        titleMedium: text500,
        titleSmall: text500,
        bodyLarge: text400,
        bodyMedium: text400,
        bodySmall: text400,
        labelLarge: text400,
        labelMedium: text400,
        labelSmall: text400,

        headlineSmall: text500.copyWith(fontSize: 16),
        headlineMedium: text500.copyWith(fontSize: 18),
        headlineLarge: text500.copyWith(fontSize: 20),
      ),

      colorScheme: const ColorScheme.dark(
        surface: background,
        primary: primary,
        secondary: primary,
        error: error,
        onSurface: text,
        onPrimary: text,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text600.copyWith(fontSize: 16),
      ),

      dividerTheme: const DividerThemeData(color: divider, thickness: 1),

      cardTheme: const CardThemeData(
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: dialogBg,
        surfaceTintColor: Colors.transparent,

        headerBackgroundColor: headerBg,
        headerForegroundColor: text,
        headerHeadlineStyle: text600.copyWith(fontSize: 18),
        headerHelpStyle: text400.copyWith(fontSize: 12, color: textInactive),

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

        cancelButtonStyle: textButton.copyWith(
          foregroundColor: WidgetStatePropertyAll(textMuted),
          textStyle: WidgetStatePropertyAll(text500),
        ),

        confirmButtonStyle: textButton.copyWith(
          foregroundColor: WidgetStatePropertyAll(primary),
          textStyle: WidgetStatePropertyAll(text600),
        ),

        shape: const RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: separator, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButton),

      textButtonTheme: TextButtonThemeData(style: textButton),

      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButton),

      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(false),
        thickness: WidgetStateProperty.all(4),
        radius: const Radius.circular(3),
        thumbColor: WidgetStateProperty.all(scrollbarBg),
        crossAxisMargin: -11,
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: buttonBg,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        contentTextStyle: text500,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(color: tooltipBg, borderRadius: BorderRadius.all(Radius.circular(2))),
        textStyle: text400.copyWith(color: tooltipFg, fontSize: 12),
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(tableHeaderBg),
        headingTextStyle: text500.copyWith(fontSize: 14),
        headingRowHeight: tableHeadingRowHeight,
        dataRowColor: WidgetStateProperty.all(tableRowBg),
        dataTextStyle: text400.copyWith(fontSize: 13),
        dataRowMinHeight: tableDataRowMinHeight,
        dividerThickness: 1,
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
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
        side: const BorderSide(color: inputBorderFocused, width: 1),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),

      bottomSheetTheme: const BottomSheetThemeData(modalBarrierColor: barrierBg),

      dialogTheme: DialogThemeData(
        backgroundColor: dialogBg,
        surfaceTintColor: dialogBg,
        barrierColor: barrierBg,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: separator, width: 1),
        ),
        titleTextStyle: text600.copyWith(fontSize: 18),
        contentTextStyle: text400.copyWith(fontSize: 14),
        iconColor: action,
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: menuDecoration.style,
        textStyle: text400.copyWith(fontSize: 14),
        inputDecorationTheme: inputDecoration,
      ),
    );
  }
}
