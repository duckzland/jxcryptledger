import 'package:flutter/material.dart';

import '../app/theme.dart';

void widgetsNotifySuccess(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.primary,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}

void widgetsNotifyError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.error,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}

void widgetsNotifyWarning(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.warning,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}
