import 'package:flutter/material.dart';
import 'package:jxledger/app/theme.dart';

import '../../../widgets/text/balance.dart';

class TransactionsWidgetsPanelItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double comparator;
  final bool? selectable;

  const TransactionsWidgetsPanelItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.value = 0.0,
    this.comparator = 0.0,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        SizedBox(height: 1),
        RepaintBoundary(
          child: WidgetsTextBalance(text: subtitle, value: value, comparator: comparator, fontSize: 13, selectable: selectable),
        ),
      ],
    );
  }
}
