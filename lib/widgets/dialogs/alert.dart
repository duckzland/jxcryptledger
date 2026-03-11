import 'package:flutter/material.dart';
import '../button.dart';

class WidgetsDialogsAlert extends StatefulWidget {
  final Future<void> Function(BuildContext dialogContext) onPressed;

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

  const WidgetsDialogsAlert({
    super.key,
    required this.onPressed,

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
  });

  @override
  State<WidgetsDialogsAlert> createState() => _WidgetsDialogsAlertState();
}

class _WidgetsDialogsAlertState extends State<WidgetsDialogsAlert> {
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
              WidgetsButton(label: widget.dialogCancelLabel, onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: widget.dialogConfirmLabel,
                initialState: widget.initialState,
                onPressed: (_) => widget.onPressed(dialogContext),
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
