import 'package:flutter/material.dart';

import '../app/theme.dart';

void notifySuccess(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.primary,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}

void notifyError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.error,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}

void notifyWarning(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.warning,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}
