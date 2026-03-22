import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:jxledger/widgets/notify.dart';

import '../../core/log.dart';
import '../button.dart';

class WidgetsDialogsExport extends StatefulWidget {
  final Future<String> Function() onExport;

  final String? label;
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final EdgeInsets padding;
  final Size? minimumSize;
  final WidgetsButtonActionState initialState;

  final void Function(WidgetsButtonState s)? evaluator;
  final bool Function()? isEmpty;

  final String dialogTitle;
  final String dialogMessage;
  final String dialogCancelLabel;
  final String dialogExportLabel;

  final String suggestedPrefix;

  const WidgetsDialogsExport({
    super.key,
    required this.onExport,

    this.label,
    this.tooltip = "Export data",
    this.icon = Icons.arrow_upward,
    this.iconSize = 20,
    this.padding = const EdgeInsets.all(8),
    this.minimumSize = const Size(40, 40),
    this.initialState = WidgetsButtonActionState.action,
    this.evaluator,
    this.isEmpty,

    this.dialogTitle = "Export Data",
    this.dialogMessage = "This will export your data to a JSON file.",
    this.dialogCancelLabel = "Cancel",
    this.dialogExportLabel = "Export",

    this.suggestedPrefix = 'exp_',
  });

  @override
  State<WidgetsDialogsExport> createState() => _WidgetsDialogsExportState();
}

class _WidgetsDialogsExportState extends State<WidgetsDialogsExport> {
  Future<void> _selectAndExport() async {
    try {
      final json = await widget.onExport();
      if (json.isEmpty) {
        widgetsNotifyError("Failed to export data.");
        return;
      }

      final suggestedName = "${widget.suggestedPrefix}${DateTime.now().millisecondsSinceEpoch}.json";

      final saveLocation = await getSaveLocation(suggestedName: suggestedName, confirmButtonText: "Save");

      if (saveLocation == null || saveLocation.path.isEmpty) {
        widgetsNotifyError("Export cancelled.");
        return;
      }

      final file = File(saveLocation.path);
      await file.writeAsString(json);

      widgetsNotifySuccess("Export completed successfully.");
    } catch (e) {
      logln("[EXPORT] Failed to save export file: $e");
      widgetsNotifyError("Failed to export data.");
    }
  }

  Future<void> _showDialog(BuildContext context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth;
    if (screenWidth > 360) {
      dialogWidth = 300;
    } else {
      dialogWidth = screenWidth * 0.9;
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
                    label: widget.dialogExportLabel,
                    initialState: widget.initialState,
                    onPressed: (_) async {
                      Navigator.pop(dialogContext);
                      await _selectAndExport();
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
      s.action();
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
    );
  }
}
