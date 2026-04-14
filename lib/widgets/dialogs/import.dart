import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/exceptions.dart';
import '../../core/log.dart';
import '../button.dart';
import '../notify.dart';
import 'alert.dart';

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
  final bool persistBg;

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
    this.persistBg = false,

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

  Future<void> _handlePressed(BuildContext context) async {
    await _selectAndImport();
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsDialogsAlert(
      dialogTitle: widget.dialogTitle,
      dialogMessage: widget.dialogMessage,
      dialogCancelLabel: widget.dialogCancelLabel,
      dialogConfirmLabel: widget.dialogImportLabel,
      actionCompleteCallback: widget.showDialogBeforeImport ? _selectAndImport : null,
      label: widget.label,
      tooltip: widget.tooltip,
      icon: widget.icon,
      iconSize: widget.iconSize,
      padding: widget.padding,
      minimumSize: widget.minimumSize,
      initialState: widget.initialState,
      evaluator: widget.evaluator,
      onPressed: widget.showDialogBeforeImport ? null : _handlePressed,
    );
  }
}
