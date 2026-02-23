import 'package:flutter/material.dart';

import '../../widgets/button.dart';
import '../../core/locator.dart';
import 'form.dart';
import 'model.dart';
import 'repository.dart';

enum TransactionsButtonsMode { edit, close, trade }

class TransactionsButtons extends StatelessWidget {
  final TransactionsModel tx;
  final void Function(TransactionsButtonsMode mode, TransactionsModel tx) onAction;

  TransactionsRepository get repo => locator<TransactionsRepository>();

  const TransactionsButtons({super.key, required this.tx, required this.onAction});

  bool _checkVisibility(TransactionsButtonsMode mode) {
    switch (mode) {
      case TransactionsButtonsMode.edit:
        return true; // always editable
      case TransactionsButtonsMode.close:
        return tx.pid == '0'; // example rule
      case TransactionsButtonsMode.trade:
        return tx.balance > 0; // example rule
    }
  }

  Future<void> _actionEdit(TransactionsModel newTx) async {
    // Example real logic:
    // - validate
    // - update DB
    // - update parent/children
    // - recalc balances
    // - etc.

    // await repo.update(newTx);

    // notify parent
    onAction(TransactionsButtonsMode.edit, newTx);
  }

  Future<void> _actionClose() async {
    // Example real logic:
    // - mark closed
    // - update DB
    // - cascade close children
    // - recalc balances

    // await repo.close(tx);

    onAction(TransactionsButtonsMode.close, tx);
  }

  Future<void> _actionTrade(TransactionsModel newTx) async {
    // Example real logic:
    // - validate trade
    // - create child transaction
    // - update parent balance
    // - recalc totals

    // await repo.trade(tx, newTx);

    onAction(TransactionsButtonsMode.trade, newTx);
  }

  Future<void> _showEditDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => TransactionForm(
        initialData: tx,
        onSave: (newTx) async {
          await _actionEdit(newTx);
        },
      ),
    );
  }

  Future<void> _showCloseDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Close Transaction"),
        content: const Text("Are you sure you want to close this transaction?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _actionClose();
              Navigator.pop(context);
            },
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _showTradeDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => TransactionForm(
        parent: tx,
        isTrade: true,
        onSave: (newTx) async {
          await _actionTrade(newTx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (_checkVisibility(TransactionsButtonsMode.edit))
          WidgetButton(
            icon: Icons.edit,
            tooltip: "Edit",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showEditDialog(context),
          ),

        if (_checkVisibility(TransactionsButtonsMode.close))
          WidgetButton(
            icon: Icons.close,
            tooltip: "Close",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showCloseDialog(context),
          ),

        if (_checkVisibility(TransactionsButtonsMode.trade))
          WidgetButton(
            icon: Icons.swap_horiz,
            tooltip: "Trade",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showTradeDialog(context),
          ),
      ],
    );
  }
}
