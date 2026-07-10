import 'package:flutter/material.dart';
import 'package:jxledger/app/theme.dart';

import '../../../widgets/balance_text.dart';

class TransactionsWidgetsPanelItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double comparator;

  const TransactionsWidgetsPanelItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.comparator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 1),
        RepaintBoundary(
          child: WidgetsBalanceText(text: subtitle, value: value, comparator: comparator, fontSize: 13),
        ),
      ],
    );
  }
}
