import 'package:flutter/material.dart';

import '../../../widgets/button.dart';

class TransactionsDialogsNote {
  static Future<void> show(BuildContext context, {required String note}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 360 ? 300.0 : screenWidth * 0.9;

    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        actionsAlignment: MainAxisAlignment.center,
        title: const Text("Notes"),
        content: ConstrainedBox(
          constraints: BoxConstraints(minWidth: dialogWidth),
          child: Text(note),
        ),
        actions: [
          Center(
            child: WidgetsButton(label: "Close", onPressed: (_) => Navigator.pop(dialogContext)),
          ),
        ],
      ),
    );
  }
}
