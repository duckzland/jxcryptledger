import 'package:flutter/material.dart';

import '../model.dart';

class TransactionsWidgetsStatusText extends StatelessWidget {
  final TransactionStatus status;

  const TransactionsWidgetsStatusText(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TransactionStatus.active:
        return const Text('Active');
      case TransactionStatus.inactive:
        return const Text('Inactive');
      case TransactionStatus.partial:
        return const Text('Partial');
      case TransactionStatus.closed:
        return const Text('Closed');
      case TransactionStatus.finalized:
        return const Text('Finalized');
      case TransactionStatus.unknown:
        return const Text('Unknown');
    }
  }
}
