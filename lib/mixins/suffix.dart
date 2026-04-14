import 'package:flutter/material.dart';

import '../app/theme.dart';

mixin MixinsSuffix<T extends StatefulWidget> on State<T> {
  String get suffixText => "";

  void suffixOnUseMax() {}
  void suffixOnClean() {}
  void suffixOnCopy() {}

  Widget suffixIconText() {
    return Text("$suffixText ", style: TextStyle(color: AppTheme.textMuted));
  }

  Widget suffixIconUseMax(String tooltip) {
    return IconButton(
      icon: const Icon(Icons.keyboard_double_arrow_up),
      iconSize: 16,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      mouseCursor: SystemMouseCursors.click,
      tooltip: tooltip,
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppTheme.action;
          }
          return AppTheme.textMuted;
        }),
        padding: WidgetStateProperty.all(EdgeInsets.only(left: 3.0, right: 3.0, top: 5.0, bottom: 5.0)),
        minimumSize: WidgetStateProperty.all(const Size(16, 16)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: suffixOnUseMax,
    );
  }

  Widget suffixIconCopy(String tooltip) {
    return IconButton(
      icon: const Icon(Icons.copy),
      iconSize: 16,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      mouseCursor: SystemMouseCursors.click,
      tooltip: tooltip,
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppTheme.action;
          }
          return AppTheme.textMuted;
        }),
        padding: WidgetStateProperty.all(EdgeInsets.only(left: 3.0, right: 3.0, top: 5.0, bottom: 5.0)),
        minimumSize: WidgetStateProperty.all(const Size(16, 16)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: suffixOnCopy,
    );
  }

  Widget suffixIconClean(String tooltip) {
    return IconButton(
      icon: const Icon(Icons.close),
      iconSize: 16,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      mouseCursor: SystemMouseCursors.click,
      tooltip: tooltip,
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppTheme.error;
          }
          return AppTheme.textMuted;
        }),
        padding: WidgetStateProperty.all(EdgeInsets.only(left: 3.0, right: 3.0, top: 5.0, bottom: 5.0)),
        minimumSize: WidgetStateProperty.all(const Size(16, 16)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: suffixOnClean,
    );
  }
}
