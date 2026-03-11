import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:jxledger/widgets/notify.dart';

import '../../app/exceptions.dart';
import '../../core/log.dart';
import '../button.dart';

class WidgetsDialogsImport extends StatefulWidget {
  final Future<void> Function(String json) onImport;

  final bool showDialogBeforeImport;

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
  final String dialogImportLabel;

  const WidgetsDialogsImport({
    super.key,
    required this.onImport,
    this.showDialogBeforeImport = true,

    this.label,
    this.tooltip = "Import data",
    this.icon = Icons.arrow_downward,
    this.iconSize = 20,
    this.padding = const EdgeInsets.all(8),
    this.minimumSize = const Size(40, 40),
    this.initialState = WidgetsButtonActionState.primary,
    this.evaluator,

    this.dialogTitle = "Import Data",
    this.dialogMessage = "This will erase existing data before importing.\nThis action cannot be undone.",
    this.dialogCancelLabel = "Cancel",
    this.dialogImportLabel = "Import",
  });

  @override
  State<WidgetsDialogsImport> createState() => _WidgetsDialogsImportState();
}

class _WidgetsDialogsImportState extends State<WidgetsDialogsImport> {
  Future<void> _selectAndImport() async {
    try {
      const typeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) {
        widgetsNotifyError("No file selected.");
        return;
      }

      final json = await file.readAsString();
      await widget.onImport(json);

      widgetsNotifySuccess("Import completed successfully.");
    } on ValidationException catch (e) {
      widgetsNotifyError(e.userMessage);
    } catch (e) {
      logln("[IMPORT] Import failed: $e");
      widgetsNotifyError("Import failed.");
    }
  }

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
                label: widget.dialogImportLabel,
                initialState: widget.initialState,
                onPressed: (_) async {
                  try {
                    Navigator.pop(dialogContext);
                    await _selectAndImport();
                  } catch (e) {
                    widgetsNotifyError("Failed to import file.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePressed(BuildContext context) async {
    if (widget.showDialogBeforeImport) {
      await _showDialog(context);
    } else {
      await _selectAndImport();
    }
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
      onPressed: (_) => _handlePressed(context),
      evaluator: widget.evaluator,
    );
  }
}
