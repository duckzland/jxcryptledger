import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';

void widgetsNotifySuccess(String msg) {
  ScaffoldMessenger.of(rootNavigatorKey.currentContext!).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.primary,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}

void widgetsNotifyError(String msg) {
  ScaffoldMessenger.of(rootNavigatorKey.currentContext!).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.error,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}

void widgetsNotifyWarning(String msg) {
  ScaffoldMessenger.of(rootNavigatorKey.currentContext!).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.warning,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}
