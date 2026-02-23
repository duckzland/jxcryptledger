import 'package:flutter/material.dart';

import '../../core/locator.dart';
import '../../widgets/button.dart';
import 'form.dart';
import 'model.dart';
import 'repository.dart';

enum TransactionsButtonActionMode { edit, trade, close, delete }

class TransactionsButtons extends StatelessWidget {
  final TransactionsModel tx;

  final void Function(TransactionsFormActionMode mode, TransactionsModel child, TransactionsModel? parent) onAction;

  TransactionsRepository get repo => locator<TransactionsRepository>();

  const TransactionsButtons({super.key, required this.tx, required this.onAction});

  bool _checkVisibility(TransactionsButtonActionMode mode) {
    switch (mode) {
      case TransactionsButtonActionMode.edit:
        return true; // always editable

      case TransactionsButtonActionMode.close:
        return tx.pid == '0'; // example rule: only root can close

      case TransactionsButtonActionMode.trade:
        return tx.balance > 0;

      case TransactionsButtonActionMode.delete:
        return tx.rid == '0' && tx.pid == '0' && tx.statusEnum == TransactionStatus.active;
    }
  }

  Future<void> _actionEdit(TransactionsModel newTx) async {
    // Example: repo.update(newTx);
    onAction(TransactionsFormActionMode.edit, newTx, null);
  }

  Future<void> _actionClose() async {
    // Example: repo.close(tx);
    // onAction(TransactionsFormActionMode.close, tx, null);
  }

  Future<void> _actionTrade(TransactionsModel child, TransactionsModel parent) async {
    // Example: repo.trade(parent, child);
    onAction(TransactionsFormActionMode.trade, child, parent);
  }

  Future<void> _actionDelete(TransactionsModel tx) async {
    // Example: repo.trade(parent, child);
    repo.delete(tx.tid);
    onAction(TransactionsFormActionMode.edit, tx, null);
  }

  Future<void> _showEditDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => TransactionForm(
        mode: TransactionsFormActionMode.edit,
        initialData: tx,
        onSave: (mode, child, parent) async {
          await _actionEdit(child);
        },
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Transaction"),
        content: const Text(
          "Are you sure you want to delete this transaction? This action cannot be undone. Other transactions that are linked to this transaction may be affected.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _actionDelete(tx);
              //   if (context.mounted) {
              //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
              //     Navigator.pop(context);
              //   }
            },
            child: const Text("Delete"),
          ),
        ],
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
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction closed')));
                Navigator.pop(context);
              }
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
        mode: TransactionsFormActionMode.trade,
        initialData: tx,
        parent: tx,
        onSave: (mode, child, parentTx) async {
          await _actionTrade(child, parentTx!);
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
        if (_checkVisibility(TransactionsButtonActionMode.edit))
          WidgetButton(
            icon: Icons.edit,
            tooltip: "Edit",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showEditDialog(context),
          ),

        if (_checkVisibility(TransactionsButtonActionMode.close))
          WidgetButton(
            icon: Icons.close,
            tooltip: "Close",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showCloseDialog(context),
          ),

        if (_checkVisibility(TransactionsButtonActionMode.trade))
          WidgetButton(
            icon: Icons.swap_horiz,
            tooltip: "Trade",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showTradeDialog(context),
          ),

        if (_checkVisibility(TransactionsButtonActionMode.delete))
          WidgetButton(
            icon: Icons.delete,
            tooltip: "Delete",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showDeleteDialog(context),
          ),
      ],
    );
  }
}
