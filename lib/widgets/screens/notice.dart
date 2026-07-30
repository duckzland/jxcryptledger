import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../buttons/action.dart';

class WidgetsScreensNotice extends StatelessWidget {
  final String title;
  final String? btnTitle;
  final String? btnTooltip;

  final bool Function()? btnEvaluator;
  final Future<void> Function()? btnCallback;

  const WidgetsScreensNotice({super.key, required this.title, this.btnTitle, this.btnTooltip, this.btnEvaluator, this.btnCallback});

  void _evaluateAction(WidgetsButtonsActionState s) {
    if (btnEvaluator == null) return;

    if (btnEvaluator?.call() == false) {
      s.disable();
    } else {
      s.action();
    }
  }

  void _callbackAction(WidgetsButtonsActionState s) async {
    s.progress();
    await btnCallback?.call();
    s.action();
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
              if (btnTitle != null && btnCallback != null)
                WidgetsButtonsAction(
                  key: const Key("action-button"),
                  label: btnTitle,
                  tooltip: btnTooltip,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  initialState: WidgetsButtonActionState.action,
                  evaluator: _evaluateAction,
                  filledMode: true,
                  onPressed: _callbackAction,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
