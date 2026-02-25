import 'package:flutter/material.dart';

import '../../core/locator.dart';
import '../../widgets/button.dart';
import '../../widgets/notify.dart';
import '../cryptos/repository.dart';
import 'controller.dart';
import 'form.dart';
import 'model.dart';

enum TransactionsButtonActionMode { edit, trade, close, delete }

class TransactionsButtons extends StatelessWidget {
  final TransactionsModel tx;
  final void Function() onAction;
  final CryptosRepository _cryptosRepo = locator<CryptosRepository>();

  TransactionsController get _txController => locator<TransactionsController>();

  TransactionsButtons({super.key, required this.tx, required this.onAction});

  Future<void> _showEditDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => TransactionForm(
        mode: TransactionsFormActionMode.edit,
        initialData: tx,
        onSave: () async {
          Navigator.pop(dialogContext);
          onAction();
          notifySuccess(context, "${tx.srAmountText} - ${tx.balanceText} transaction updated.");
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
              await _txController.removeRoot(tx);
              onAction();
              notifySuccess(context, "${tx.srAmountText} - ${tx.balanceText} transaction deleted.");
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
              await _txController.closeLeaf(tx);
              onAction();
              notifySuccess(context, "${tx.srAmountText} - ${tx.balanceText} transaction closed.");
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
          onAction();
          notifySuccess(context, "New trading transaction created.");
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
        if (tx.isEditable)
          WidgetButton(
            icon: Icons.edit,
            tooltip: "Edit",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showEditDialog(context),
            evaluator: (s) {
              _cryptosRepo.hasAny() ? s.normal() : s.disable();
            },
          ),

        if (tx.isTradable)
          WidgetButton(
            icon: Icons.swap_horiz,
            initialState: WidgetButtonActionState.action,
            tooltip: "Trade",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showTradeDialog(context),
            evaluator: (s) {
              _cryptosRepo.hasAny() ? s.action() : s.disable();
            },
          ),

        if (tx.isDeletable)
          WidgetButton(
            icon: Icons.delete,
            initialState: WidgetButtonActionState.error,
            tooltip: "Delete",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showDeleteDialog(context),
          ),

        if (tx.isClosable)
          WidgetButton(
            icon: Icons.close,
            initialState: WidgetButtonActionState.warning,
            tooltip: "Close",
            padding: const EdgeInsets.all(8),
            iconSize: 18,
            minimumSize: const Size(36, 36),
            onPressed: (_) => _showCloseDialog(context),
          ),
      ],
    );
  }
}
