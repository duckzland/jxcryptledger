import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../buttons/action.dart';

class WidgetsScreensNotice extends StatelessWidget {
  final String title;
  final String? btnTitle;
  final String? btnTooltip;

  final IconData icon;

  final void Function(WidgetsButtonsActionState s)? btnEvaluator;
  final Future<void> Function()? btnCallback;

  const WidgetsScreensNotice({
    super.key,
    required this.title,
    this.icon = Icons.add_circle_outline,
    this.btnTitle,
    this.btnTooltip,
    this.btnEvaluator,
    this.btnCallback,
  });

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
          Icon(icon, size: 60, color: AppTheme.separator),
          SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          SizedBox(height: 24),
          Wrap(
            spacing: 20,
            children: [
              if (btnTitle != null && btnCallback != null)
                WidgetsButtonsAction(
                  key: const Key("action-button"),
                  label: btnTitle,
                  tooltip: btnTooltip,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  initialState: WidgetsButtonActionState.action,
                  evaluator: btnEvaluator,
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
