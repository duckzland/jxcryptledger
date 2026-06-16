import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../button.dart';
import '../dialogs/show_form.dart';
import '../dialogs/import.dart';

class WidgetsScreensEmpty extends StatelessWidget {
  final String title;
  final String addTitle;
  final String addTooltip;
  final String importTitle;
  final String importTooltip;

  final bool Function() addEvaluator;
  final bool Function() importEvaluator;

  final Widget Function(BuildContext context) addForm;
  final Future<void> Function(String json) importCallback;

  final bool importShow;
  final bool addShow;

  const WidgetsScreensEmpty({
    super.key,
    required this.title,
    required this.addTitle,
    required this.addTooltip,
    required this.addEvaluator,
    required this.addForm,
    this.addShow = true,
    required this.importTitle,
    required this.importTooltip,
    required this.importEvaluator,
    required this.importCallback,
    this.importShow = true,
  });

  void _evaluateAddNew(WidgetsButtonState s) {
    if (addEvaluator() == false) {
      s.disable();
    } else {
      s.action();
    }
  }

  void _evaluateImport(WidgetsButtonState s) {
    if (importEvaluator() == false) {
      s.disable();
    } else {
      s.primary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.add_circle_outline, size: 60, color: AppTheme.separator),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 20,
            children: [
              if (addShow)
                WidgetsDialogsShowForm(
                  key: const Key("add-new-button"),
                  icon: Icons.add,
                  iconSize: 16,
                  label: addTitle,
                  tooltip: addTooltip,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  buildForm: addForm,
                  evaluator: _evaluateAddNew,
                  persistBg: true,
                ),
              if (importShow)
                WidgetsDialogsImport(
                  key: const Key("import-button-new"),
                  label: importTitle,
                  tooltip: importTooltip,
                  icon: Icons.arrow_downward,
                  iconSize: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  showDialogBeforeImport: false,
                  initialState: WidgetsButtonActionState.action,
                  onImport: importCallback,
                  evaluator: _evaluateImport,
                  persistBg: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
