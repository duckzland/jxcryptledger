import 'package:flutter/material.dart';

import 'theme.dart';

void appShowSuccess(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.primary,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}

void appShowError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.error,
      content: Text(msg, style: const TextStyle(color: AppTheme.text)),
    ),
  );
}
