import 'package:flutter/material.dart';

import '../app/exceptions.dart';
import '../widgets/notify.dart';

mixin MixinsActionable {
  Future<void> actionableFormSave<T>(
    BuildContext? context, {
    BuildContext? dialogContext,
    T? data,
    Future<void> Function(T)? action,
    String successMessage = "Operation successful",
    VoidCallback? onComplete,
    Object? error,
    bool showMessage = true,
  }) async {
    if (error == null) {
      if (action != null && data != null) {
        await action(data);
      }

      if (dialogContext != null && dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      onComplete?.call();

      if (showMessage && context != null && context.mounted) {
        widgetsNotifySuccess(successMessage, ctx: context);
      }
      return;
    }

    if (error is ValidationException) {
      if (showMessage && context != null && context.mounted) {
        widgetsNotifyError(error.userMessage, ctx: context);
      }
      return;
    }

    if (showMessage && context != null && context.mounted) {
      widgetsNotifyError(error.toString(), ctx: context);
    }
  }

  Future<void> actionableAction<T>(
    BuildContext? context, {
    BuildContext? dialogContext,
    T? data,
    Future<void> Function(T)? action,
    String? successMessage = "Operation successful",
    String? errorMessage = "Operation failed",
    VoidCallback? onComplete,
    VoidCallback? onStart,
    bool showMessage = true,
  }) async {
    try {
      if (action != null && data != null) {
        await action(data);
      }

      onStart?.call();

      if (dialogContext != null && dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      onComplete?.call();

      if (showMessage && context != null && context.mounted && successMessage != null) {
        widgetsNotifySuccess(successMessage, ctx: context);
      }
    } on ValidationException catch (e) {
      if (showMessage && context != null && context.mounted) {
        widgetsNotifyError(e.userMessage, ctx: context);
      }
    } catch (e) {
      if (showMessage && context != null && context.mounted) {
        widgetsNotifyError(errorMessage ?? e.toString(), ctx: context);
      }
    }
  }
}
