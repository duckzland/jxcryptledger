import 'package:flutter/material.dart';

import '../../app/snackbar.dart';
import '../../core/locator.dart';
import '../../widgets/button.dart';
import 'controller.dart';
import 'form.dart';
import 'model.dart';

enum TransactionsButtonActionMode { edit, trade, close, delete }

class TransactionsButtons extends StatelessWidget {
  final TransactionsModel tx;
  final void Function() onAction;

  TransactionsController get controller => locator<TransactionsController>();

  const TransactionsButtons({super.key, required this.tx, required this.onAction});

  bool _checkVisibility(TransactionsButtonActionMode mode) {
    switch (mode) {
      case TransactionsButtonActionMode.edit:
        return true;
      case TransactionsButtonActionMode.close:
        return tx.pid != '0' && tx.statusEnum == TransactionStatus.active;
      case TransactionsButtonActionMode.trade:
        return tx.balance > 0;
      case TransactionsButtonActionMode.delete:
        return tx.rid == '0' && tx.pid == '0' && tx.statusEnum == TransactionStatus.active;
    }
  }

  Future<void> _actionEdit() async {
    onAction();
  }

  Future<void> _actionClose() async {
    await controller.close(tx.tid);
    onAction();
  }

  Future<void> _actionTrade() async {
    onAction();
  }

  Future<void> _actionDelete(TransactionsModel tx) async {
    await controller.removeRoot(tx.tid);
    onAction();
  }

  Future<void> _showEditDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => TransactionForm(
        mode: TransactionsFormActionMode.edit,
        initialData: tx,
        onSave: () async {
          Navigator.pop(dialogContext);
          await _actionEdit();
          appShowSuccess(context, "${tx.srAmountText} - ${tx.balanceText} transaction updated.");
        },
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Transaction"),
        content: const Text(
          "This will delete this transaction and all of its history.\n"
          "This action cannot be undone.",
        ),
        actions: [
          WidgetButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
          const SizedBox(width: 12),
          WidgetButton(
            label: 'Delete',
            initialState: WidgetButtonActionState.error,
            onPressed: (_) async {
              Navigator.pop(dialogContext);
              await _actionDelete(tx);
              appShowSuccess(context, "${tx.srAmountText} - ${tx.balanceText} transaction deleted.");
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCloseDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Close Transaction"),
        content: const Text("Are you sure you want to close this transaction?"),
        actions: [
          WidgetButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
          const SizedBox(width: 12),
          WidgetButton(
            label: 'Close',
            initialState: WidgetButtonActionState.action,
            onPressed: (_) async {
              Navigator.pop(dialogContext);
              await _actionClose();
              appShowSuccess(context, "${tx.srAmountText} - ${tx.balanceText} transaction closed.");
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showTradeDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => TransactionForm(
        mode: TransactionsFormActionMode.trade,
        initialData: tx,
        parent: tx,
        onSave: () async {
          Navigator.pop(dialogContext);
          await _actionTrade();
          appShowSuccess(context, "New trading transaction created.");
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
