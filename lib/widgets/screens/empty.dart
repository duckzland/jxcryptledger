import 'dart:async';
import 'package:flutter/material.dart';

import '../button.dart';
import '../dialogs/import.dart';

class WidgetsScreensEmpty extends StatefulWidget {
  final String title;
  final String addTitle;
  final String addTooltip;
  final String importTitle;
  final String importTooltip;

  final bool Function() addEvaluator;
  final bool Function() importEvaluator;
  final Widget Function(BuildContext context) addForm;
  final Future<void> Function(String json) importCallback;

  const WidgetsScreensEmpty({
    super.key,
    required this.title,
    required this.addTitle,
    required this.addTooltip,
    required this.addEvaluator,
    required this.addForm,
    required this.importTitle,
    required this.importTooltip,
    required this.importEvaluator,
    required this.importCallback,
  });

  @override
  State<WidgetsScreensEmpty> createState() => _WidgetsScreensEmptyState();
}

class _WidgetsScreensEmptyState extends State<WidgetsScreensEmpty> {
  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: widget.addForm(dialogContext)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.add_circle_outline, size: 60, color: Colors.white30),
          const SizedBox(height: 16),
          Text(widget.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            children: [
              WidgetsButton(
                icon: Icons.add,
                iconSize: 16,
                label: widget.addTitle,
                tooltip: widget.addTooltip,
                initialState: WidgetsButtonActionState.action,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                onPressed: (_) => _showAddDialog(),
                evaluator: (s) {
                  if (widget.addEvaluator() == false) {
                    s.disable();
                  } else {
                    s.action();
                  }
                },
              ),
              WidgetsDialogsImport(
                key: const Key("import-button-new"),
                label: widget.importTitle,
                tooltip: widget.importTooltip,
                icon: Icons.arrow_downward,
                iconSize: 16,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                showDialogBeforeImport: false,
                onImport: widget.importCallback,
                evaluator: (s) {
                  if (widget.importEvaluator() == false) {
                    s.disable();
                  } else {
                    s.primary();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
