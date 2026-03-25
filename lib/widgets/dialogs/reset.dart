import 'package:flutter/material.dart';
import 'package:jxledger/widgets/notify.dart';

import '../../core/log.dart';
import '../button.dart';

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
  Future<void> _showDialog(BuildContext context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth;
    if (screenWidth > 360) {
      dialogWidth = 300; // mobile: almost full width
    } else {
      dialogWidth = screenWidth * 0.9; // desktop/web: half width
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: Text(widget.dialogTitle),
            content: ConstrainedBox(
              constraints: BoxConstraints(minWidth: dialogWidth),
              child: Text(widget.dialogMessage),
            ),
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
                    label: widget.dialogWipeLabel,
                    initialState: WidgetsButtonActionState.error,
                    onPressed: (_) async {
                      try {
                        await widget.onWipe();
                        Navigator.pop(dialogContext);
                        widgetsNotifySuccess("Database reset complete.");
                      } catch (e) {
                        logln("[WIPE] Failed to reset database: $e");
                        widgetsNotifyError("Failed to reset database.");
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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

    return WidgetsButton(
      label: widget.label,
      tooltip: widget.tooltip,
      icon: widget.icon,
      iconSize: widget.iconSize,
      padding: widget.padding,
      minimumSize: widget.minimumSize,
      initialState: widget.initialState,
      onPressed: (_) => _showDialog(context),
      evaluator: evaluator,
      persistBg: widget.persistBg,
    );
  }
}
