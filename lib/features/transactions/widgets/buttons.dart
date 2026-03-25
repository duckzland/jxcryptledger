import 'package:flutter/material.dart';

import '../../../mixins/actions.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/dialogs/show_form.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../forms/edit.dart';
import '../forms/trade.dart';
import '../model.dart';

class TransactionsWidgetsButtons extends StatelessWidget with MixinsActions {
  final TransactionsModel tx;
  final CryptosController cryptosController;
  final TransactionsController txController;
  final void Function() onAction;

  const TransactionsWidgetsButtons({
    super.key,
    required this.tx,
    required this.txController,
    required this.cryptosController,
    required this.onAction,
  });
  @override
  Widget build(BuildContext context) {
    final isTradable = txController.isTradable(tx);
    final isClosable = txController.isClosable(tx);
    final isDeletable = txController.isDeletable(tx);
    final isUpdatable = txController.isUpdatable(tx);
    final isRefundable = txController.isRefundable(tx);
    final hasLeaf = txController.hasLeaf(tx);
    final ptx = txController.getParent(tx);

    final sourceSymbol = cryptosController.getSymbol(tx.srId) ?? "";
    final targetSymbol = cryptosController.getSymbol(tx.rrId) ?? "";

    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (isUpdatable && tx.isActive && !hasLeaf)
          WidgetsDialogsShowForm(
            key: Key("edit-button-${tx.tid}"),
            icon: Icons.edit,
            tooltip: "Edit this transaction",
            padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
            iconSize: 16,
            minimumSize: const Size(34, 34),
            evaluator: (s) {
              !cryptosController.isEmpty() ? s.normal() : s.disable();
            },
            buildForm: (dialogContext) {
              return TransactionFormEdit(
                initialData: tx,
                parent: ptx,
                onSave: (e) => doFormSave<TransactionsModel>(
                  context,
                  dialogContext: dialogContext,
                  onComplete: onAction,
                  successMessage: "${tx.srAmountText} - ${tx.balanceText} transaction updated.",
                  error: e,
                ),
              );
            },
          ),

        if (isTradable)
          WidgetsDialogsShowForm(
            key: Key("trade-button-${tx.tid}"),
            icon: Icons.swap_horiz,
            initialState: WidgetsButtonActionState.action,
            tooltip: "Trade this transaction",
            padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
            iconSize: 18,
            minimumSize: const Size(34, 34),
            evaluator: (s) {
              !cryptosController.isEmpty() ? s.action() : s.disable();
            },
            buildForm: (dialogContext) {
              return TransactionFormTrade(
                initialData: tx,
                parent: ptx,
                onSave: (e) => doFormSave<TransactionsModel>(
                  context,
                  dialogContext: dialogContext,
                  onComplete: onAction,
                  successMessage: "New trading transaction created.",
                  error: e,
                ),
              );
            },
          ),

        if (isDeletable)
          WidgetsDialogsAlert(
            key: Key("delete-button-${tx.tid}"),
            icon: Icons.delete,
            initialState: WidgetsButtonActionState.error,
            tooltip: "Delete this transaction",
            padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
            iconSize: 18,
            minimumSize: const Size(34, 34),
            dialogTitle: "Delete Transaction",
            dialogMessage:
                "This will delete this transaction and all of its history.\n"
                "This action cannot be undone.",
            dialogConfirmLabel: "Delete",
            actionData: tx,
            actionCallback: txController.removeRoot,
            actionCompleteCallback: onAction,
            actionSuccessMessage: "${tx.srAmountText} $sourceSymbol - ${tx.balanceText} $targetSymbol transaction deleted.",
          ),

        if (isRefundable)
          WidgetsDialogsAlert(
            key: Key("refund-button-${tx.tid}"),
            icon: Icons.u_turn_left,
            initialState: WidgetsButtonActionState.error,
            tooltip: "Refund this transaction",
            padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
            iconSize: 18,
            minimumSize: const Size(34, 34),
            dialogTitle: "Refund Transaction",
            dialogMessage:
                "This will cancel this transaction and refund the balance back to its parent transaction.\n"
                "This action cannot be undone.",
            dialogConfirmLabel: "Refund",
            actionData: tx,
            actionCallback: txController.removeLeaf,
            actionCompleteCallback: onAction,
            actionSuccessMessage: "${tx.srAmountText} $sourceSymbol - ${tx.balanceText} $targetSymbol transaction deleted.",
          ),

        if (isClosable)
          WidgetsDialogsAlert(
            key: Key("close-button-${tx.tid}"),
            icon: Icons.close,
            initialState: WidgetsButtonActionState.warning,
            tooltip: "Close this transaction",
            padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
            iconSize: 18,
            minimumSize: const Size(34, 34),
            dialogTitle: "Close Transaction",
            dialogMessage: "Are you sure you want to close this transaction?",
            dialogConfirmLabel: "Close",
            actionData: tx,
            actionCallback: txController.closeLeaf,
            actionCompleteCallback: onAction,
            actionSuccessMessage: "${tx.srAmountText} - ${tx.balanceText} transaction closed.",
          ),
      ],
    );
  }
}
