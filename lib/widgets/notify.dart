import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../core/locator.dart';
import '../ipc/client.dart';
import '../ipc/status/op.dart';

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
      backgroundColor: AppTheme.notifyBgSuccess,
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.notifyFgSuccess, fontWeight: AppTheme.notifyFontWeight, fontSize: AppTheme.notifyFontSize),
      ),
    ),
  );
}

void widgetsNotifyError(String msg, {BuildContext? ctx}) {
  final context = _resolveContext(ctx);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.notifyBgError,
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.notifyFgError, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter'),
      ),
    ),
  );
}

void widgetsNotifyWarning(String msg, {BuildContext? ctx}) {
  final context = _resolveContext(ctx);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.notifyBgWarning,
      content: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.notifyFgWarning, fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter'),
      ),
    ),
  );
}

void widgetsNotifyBroadcast(String key, String payload) async {
  final ipcClient = CoreLocator.getit<IpcClient>();
  await ipcClient.send(op: IpcStatusOp.getCode("broadcast"), action: "notify", key: key, payload: payload);
}
