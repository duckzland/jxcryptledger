import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../core/locator.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/dialogs/show_form.dart';
import '../../../widgets/notify.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../forms/edit.dart';
import '../forms/trade.dart';
import '../model.dart';

class TransactionsWidgetsButtons extends StatelessWidget {
  final TransactionsModel tx;
  final void Function() onAction;

  CryptosController get _cryptosController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  const TransactionsWidgetsButtons({super.key, required this.tx, required this.onAction});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object?>>(
      future: Future.wait([
        _txController.isTradable(tx),
        _txController.isClosable(tx),
        _txController.isDeletable(tx),
        _txController.isUpdatable(tx),
        _txController.isRefundable(tx),
        _txController.hasLeaf(tx),
        _txController.getParent(tx),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final isTradable = snapshot.data![0] as bool;
        final isClosable = snapshot.data![1] as bool;
        final isDeletable = snapshot.data![2] as bool;
        final isUpdatable = snapshot.data![3] as bool;
        final isRefundable = snapshot.data![4] as bool;
        final hasLeaf = snapshot.data![5] as bool;
        final ptx = snapshot.data![6] as TransactionsModel?;

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
                  _cryptosController.isEmpty() ? s.normal() : s.disable();
                },
                buildForm: (dialogContext) {
                  return TransactionFormEdit(
                    initialData: tx,
                    parent: ptx,
                    onSave: (e) async {
                      if (e == null) {
                        Navigator.pop(dialogContext);
                        onAction();
                        widgetsNotifySuccess("${tx.srAmountText} - ${tx.balanceText} transaction updated.");
                        return;
                      }

                      if (e is ValidationException) {
                        widgetsNotifyError(e.userMessage, ctx: context);
                        return;
                      }

                      widgetsNotifyError(e.toString(), ctx: context);
                    },
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
                  _cryptosController.isEmpty() ? s.action() : s.disable();
                },
                buildForm: (dialogContext) {
                  return TransactionFormTrade(
                    initialData: tx,
                    parent: ptx,
                    onSave: (e) async {
                      if (e == null) {
                        Navigator.pop(dialogContext);
                        onAction();
                        widgetsNotifySuccess("New trading transaction created.");
                        return;
                      }

                      if (e is ValidationException) {
                        widgetsNotifyError(e.userMessage, ctx: context);
                        return;
                      }

                      widgetsNotifyError(e.toString(), ctx: context);
                    },
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
                onPressed: (dialogContext) async {
                  try {
                    await _txController.removeRoot(tx);

                    Navigator.pop(dialogContext);
                    onAction();

                    String sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? "";
                    String targetSymbol = _cryptosController.getSymbol(tx.rrId) ?? "";

                    widgetsNotifySuccess("${tx.srAmountText} $sourceSymbol - ${tx.balanceText} $targetSymbol transaction deleted.");
                  } on ValidationException catch (e) {
                    widgetsNotifyError(e.userMessage);
                  } catch (e) {
                    widgetsNotifyError(e.toString());
                  }
                },
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
                onPressed: (dialogContext) async {
                  try {
                    await _txController.removeLeaf(tx);

                    Navigator.pop(dialogContext);
                    onAction();

                    String sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? "";
                    String targetSymbol = _cryptosController.getSymbol(tx.rrId) ?? "";

                    widgetsNotifySuccess("${tx.srAmountText} $sourceSymbol - ${tx.balanceText} $targetSymbol transaction deleted.");
                  } on ValidationException catch (e) {
                    widgetsNotifyError(e.userMessage);
                  } catch (e) {
                    widgetsNotifyError(e.toString());
                  }
                },
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
                onPressed: (dialogContext) async {
                  try {
                    await _txController.closeLeaf(tx);

                    Navigator.pop(dialogContext);
                    onAction();

                    widgetsNotifySuccess("${tx.srAmountText} - ${tx.balanceText} transaction closed.");
                  } on ValidationException catch (e) {
                    Navigator.pop(dialogContext);
                    widgetsNotifyError(e.userMessage);
                  } catch (e) {
                    Navigator.pop(dialogContext);
                    widgetsNotifyError(e.toString());
                  }
                },
              ),
          ],
        );
      },
    );
  }
}
