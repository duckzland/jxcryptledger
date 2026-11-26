import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../model.dart';

class TransactionsWidgetsStatusText extends StatelessWidget {
  final TransactionStatus status;
  final bool iconMode;

  const TransactionsWidgetsStatusText(this.status, {super.key, this.iconMode = false});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TransactionStatus.active => ('Active', AppTheme.buttonBgActive),
      TransactionStatus.partial => ('Partial', AppTheme.buttonBgAction),
      TransactionStatus.inactive => ('Inactive', AppTheme.buttonBgMuted),
      TransactionStatus.closed => ('Closed', AppTheme.buttonBgMuted),
      TransactionStatus.finalized => ('Finalized', AppTheme.buttonBgMuted),
      TransactionStatus.unknown => ('Unknown', AppTheme.buttonBgMuted),
    };

    if (!iconMode) {
      return Text(label);
    }

    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label[0],
        style: const TextStyle(color: AppTheme.buttonFg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
