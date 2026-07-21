import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/log.dart';
import '../buttons/action.dart';
import '../notify.dart';
import 'alert.dart';

class WidgetsDialogsExport extends StatefulWidget {
  final Future<String> Function() onExport;

  final String? label;
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final double radius;
  final EdgeInsets padding;
  final Size? minimumSize;
  final WidgetsButtonActionState initialState;
  final bool filledMode;
  final bool ghostMode;
  final bool plainMode;
  final bool centerMode;

  final Listenable? listener;

  final void Function(WidgetsButtonsActionState s)? evaluator;
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
    this.radius = 6.0,
    this.padding = const EdgeInsets.all(8),
    this.minimumSize = const Size(40, 40),
    this.initialState = WidgetsButtonActionState.action,
    this.evaluator,
    this.isEmpty,
    this.filledMode = false,
    this.ghostMode = false,
    this.plainMode = false,
    this.centerMode = true,
    this.listener,

    this.dialogTitle = "Export Data",
    this.dialogMessage = "This will export your data to a JSON file.",
    this.dialogCancelLabel = "Cancel",
    this.dialogExportLabel = "Export",

    this.suggestedPrefix = 'exp_',
  });

  @override
  State<WidgetsDialogsExport> createState() => _WidgetsDialogsExportState();

  WidgetsDialogsExport copyWith({
    String? label,
    String? tooltip,
    IconData? icon,
    double? iconSize,
    double? radius,
    EdgeInsets? padding,
    Size? minimumSize,
    WidgetsButtonActionState? initialState,
    void Function(WidgetsButtonsActionState s)? evaluator,
    bool? filledMode,
    bool? ghostMode,
    bool? plainMode,
    bool? centerMode,
    Listenable? listener,
    String? dialogTitle,
    String? dialogMessage,
    String? dialogCancelLabel,
    String? dialogExportLabel,
    String? suggestedPrefix,
    Future<String> Function()? onExport,
  }) {
    return WidgetsDialogsExport(
      label: label ?? this.label,
      tooltip: tooltip ?? this.tooltip,
      icon: icon ?? this.icon,
      iconSize: iconSize ?? this.iconSize,
      radius: radius ?? this.radius,
      padding: padding ?? this.padding,
      minimumSize: minimumSize ?? this.minimumSize,
      initialState: initialState ?? this.initialState,
      evaluator: evaluator ?? this.evaluator,
      filledMode: filledMode ?? this.filledMode,
      ghostMode: ghostMode ?? this.ghostMode,
      plainMode: plainMode ?? this.plainMode,
      centerMode: centerMode ?? this.centerMode,
      listener: listener ?? this.listener,
      dialogTitle: dialogTitle ?? this.dialogTitle,
      dialogMessage: dialogMessage ?? this.dialogMessage,
      dialogCancelLabel: dialogCancelLabel ?? this.dialogCancelLabel,
      dialogExportLabel: dialogExportLabel ?? this.dialogExportLabel,
      suggestedPrefix: suggestedPrefix ?? this.suggestedPrefix,
      onExport: onExport ?? this.onExport,
    );
  }
}

class _WidgetsDialogsExportState extends State<WidgetsDialogsExport> {
  void _selectAndExport() async {
    try {
      final json = await widget.onExport();
      if (json.isEmpty) {
        widgetsNotifyError("Failed to export data.");
        return;
      }

      final suggestedName = "${widget.suggestedPrefix}${DateTime.now().millisecondsSinceEpoch}.json";

      final saveLocation = await getSaveLocation(suggestedName: suggestedName, confirmButtonText: "Save");

      if (saveLocation == null || saveLocation.path.isEmpty) {
        // widgetsNotifyError("Export cancelled.");
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

  void _evaluate(WidgetsButtonsActionState s) {
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
    void Function(WidgetsButtonsActionState s)? evaluator = widget.evaluator;
    if (evaluator == null && widget.isEmpty != null) {
      evaluator = _evaluate;
    }

    return WidgetsDialogsAlert(
      dialogTitle: widget.dialogTitle,
      dialogMessage: widget.dialogMessage,
      dialogCancelLabel: widget.dialogCancelLabel,
      dialogConfirmLabel: widget.dialogExportLabel,
      actionCompleteCallback: _selectAndExport,
      label: widget.label,
      tooltip: widget.tooltip,
      icon: widget.icon,
      iconSize: widget.iconSize,
      radius: widget.plainMode ? 0.0 : widget.radius,
      padding: widget.padding,
      minimumSize: widget.minimumSize,
      initialState: widget.plainMode ? WidgetsButtonActionState.normal : widget.initialState,
      evaluator: evaluator,
      filledMode: widget.filledMode,
      ghostMode: widget.ghostMode,
      plainMode: widget.plainMode,
      centerMode: widget.centerMode,
      listener: widget.listener,
    );
  }
}
