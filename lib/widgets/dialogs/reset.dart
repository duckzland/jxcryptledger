import 'package:flutter/material.dart';
import '../button.dart';
import 'alert.dart';

class WidgetsDialogsReset extends StatefulWidget {
  final Future<void> Function() onWipe;

  final String? label;
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final EdgeInsets padding;
  final Size? minimumSize;
  final WidgetsButtonActionState initialState;
  final void Function(WidgetsButtonState s)? evaluator;
  final bool Function()? isEmpty;
  final bool persistBg;

  final String dialogTitle;
  final String dialogMessage;
  final String dialogCancelLabel;
  final String dialogWipeLabel;

  const WidgetsDialogsReset({
    super.key,
    required this.onWipe,

    this.label,
    this.tooltip = "Reset database",
    this.icon = Icons.delete_sweep,
    this.iconSize = 20,
    this.padding = const EdgeInsets.all(8),
    this.minimumSize = const Size(40, 40),
    this.initialState = WidgetsButtonActionState.error,
    this.evaluator,
    this.isEmpty,
    this.persistBg = false,

    this.dialogTitle = "Reset Database",
    this.dialogMessage =
        "Are you sure you want to reset the database?\n"
        "This will remove all entries and create an empty database.\n"
        "This action cannot be undone.",
    this.dialogCancelLabel = "Cancel",
    this.dialogWipeLabel = "Reset",
  });

  @override
  State<WidgetsDialogsReset> createState() => _WidgetsDialogsResetState();
}

class _WidgetsDialogsResetState extends State<WidgetsDialogsReset> {
  void _evaluate(WidgetsButtonState s) {
    if (widget.isEmpty == null) {
      return;
    }

    if (widget.isEmpty!()) {
      s.disable();
    } else {
      s.error();
    }
  }

  @override
  Widget build(BuildContext context) {
    void Function(WidgetsButtonState s)? evaluator = widget.evaluator;
    if (evaluator == null && widget.isEmpty != null) {
      evaluator = _evaluate;
    }

    return WidgetsDialogsAlert(
      dialogTitle: widget.dialogTitle,
      dialogMessage: widget.dialogMessage,
      dialogCancelLabel: widget.dialogCancelLabel,
      dialogConfirmLabel: widget.dialogWipeLabel,
      actionStartCallback: widget.onWipe,
      label: widget.label,
      tooltip: widget.tooltip,
      icon: widget.icon,
      iconSize: widget.iconSize,
      padding: widget.padding,
      minimumSize: widget.minimumSize,
      initialState: widget.initialState,
      evaluator: evaluator,
      persistBg: widget.persistBg,
    );
  }
}
