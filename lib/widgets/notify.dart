import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';

BuildContext _resolveContext(BuildContext? ctx) {
  return ctx ?? rootNavigatorKey.currentContext!;
}

void widgetsNotifyClear({BuildContext? ctx}) {
  final context = _resolveContext(ctx);
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
}

void widgetsNotifySuccess(String msg, {BuildContext? ctx}) {
  final context = _resolveContext(ctx);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.primary,
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.text),
      ),
    ),
  );
}

void widgetsNotifyError(String msg, {BuildContext? ctx}) {
  final context = _resolveContext(ctx);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.error,
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.text),
      ),
    ),
  );
}

void widgetsNotifyWarning(String msg, {BuildContext? ctx}) {
  final context = _resolveContext(ctx);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.warning,
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.text),
      ),
    ),
  );
}
