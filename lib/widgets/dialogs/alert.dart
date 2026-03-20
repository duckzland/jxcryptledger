import 'package:flutter/material.dart';
import '../../mixins/actions.dart';
import '../button.dart';

class WidgetsDialogsAlert<T> extends StatefulWidget with MixinsActions {
  final String? label;
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final EdgeInsets padding;
  final Size? minimumSize;
  final WidgetsButtonActionState initialState;
  final void Function(WidgetsButtonState s)? evaluator;

  final String dialogTitle;
  final String dialogMessage;
  final String dialogCancelLabel;
  final String dialogConfirmLabel;

  final T? actionData;
  final String? actionSuccessMessage;
  final String? actionErrorMessage;
  final Future<void> Function(T)? actionCallback;
  final VoidCallback? actionCompleteCallback;
  final VoidCallback? actionStartCallback;

  const WidgetsDialogsAlert({
    super.key,

    this.label,
    this.tooltip = "Confirm action",
    this.icon = Icons.warning_amber_rounded,
    this.iconSize = 20,
    this.padding = const EdgeInsets.all(8),
    this.minimumSize = const Size(40, 40),
    this.initialState = WidgetsButtonActionState.error,
    this.evaluator,

    this.dialogTitle = "Are you sure?",
    this.dialogMessage = "This action cannot be undone.",
    this.dialogCancelLabel = "Cancel",
    this.dialogConfirmLabel = "Confirm",

    this.actionData,
    this.actionSuccessMessage,
    this.actionErrorMessage,
    this.actionCompleteCallback,
    this.actionCallback,
    this.actionStartCallback,
  });

  @override
  State<WidgetsDialogsAlert<T>> createState() => _WidgetsDialogsAlertState<T>();
}

class _WidgetsDialogsAlertState<T> extends State<WidgetsDialogsAlert<T>> with MixinsActions {
  Future<void> _showDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: Text(widget.dialogTitle),
            content: Text(widget.dialogMessage),

            actions: [
              Wrap(
                direction: Axis.horizontal,
                runSpacing: 14,
                spacing: 10,
                runAlignment: WrapAlignment.center,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  WidgetsButton(label: widget.dialogCancelLabel, onPressed: (_) => Navigator.pop(dialogContext)),
                  WidgetsButton(
                    label: widget.dialogConfirmLabel,
                    initialState: widget.initialState,
                    onPressed: (_) => doAction<T>(
                      context,
                      dialogContext: dialogContext,
                      data: widget.actionData,
                      action: widget.actionCallback,
                      onStart: widget.actionStartCallback,
                      onComplete: widget.actionCompleteCallback,
                      successMessage: widget.actionSuccessMessage,
                      errorMessage: widget.actionErrorMessage,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsButton(
      label: widget.label,
      tooltip: widget.tooltip,
      icon: widget.icon,
      iconSize: widget.iconSize,
      padding: widget.padding,
      minimumSize: widget.minimumSize,
      initialState: widget.initialState,
      onPressed: (_) => _showDialog(context),
      evaluator: widget.evaluator,
    );
  }
}
