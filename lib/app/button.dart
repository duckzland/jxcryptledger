import 'package:flutter/material.dart';

import 'theme.dart';

Widget appButton({required String label, required VoidCallback onPressed, Color? background, Color? foreground}) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: background ?? AppTheme.buttonBg,
      foregroundColor: foreground ?? AppTheme.text,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      elevation: 2,
    ).copyWith(mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click)),
    onPressed: onPressed,
    child: Text(label),
  );
}
