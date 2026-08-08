import 'package:flutter/material.dart';

import '../model.dart';

class TransactionsWidgetsStatusText extends StatelessWidget {
  final TransactionStatus status;

  const TransactionsWidgetsStatusText(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TransactionStatus.active:
        return Text('Active');
      case TransactionStatus.inactive:
        return Text('Inactive');
      case TransactionStatus.partial:
        return Text('Partial');
      case TransactionStatus.closed:
        return Text('Closed');
      case TransactionStatus.finalized:
        return Text('Finalized');
      case TransactionStatus.unknown:
        return Text('Unknown');
    }
  }
}
