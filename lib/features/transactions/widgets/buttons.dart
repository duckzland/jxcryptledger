import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../core/locator.dart';
import '../../../widgets/button.dart';
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

  Future<void> _showDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Delete Transaction"),
            content: const Text(
              "This will delete this transaction and all of its history.\n"
              "This action cannot be undone.",
            ),
            actions: [
              WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: 'Delete',
                initialState: WidgetsButtonActionState.error,
                onPressed: (_) async {
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRefundDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Refund Transaction"),
            content: const Text(
              "This will cancel this transaction and refund the balance back to its parent transaction.\n"
              "This action cannot be undone.",
            ),
            actions: [
              WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: 'Refund',
                initialState: WidgetsButtonActionState.error,
                onPressed: (_) async {
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCloseDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
            actionsAlignment: MainAxisAlignment.center,
            title: const Text("Close Transaction"),
            content: const Text("Are you sure you want to close this transaction?"),
            actions: [
              WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetsButton(
                label: 'Close',
                initialState: WidgetsButtonActionState.action,
                onPressed: (_) async {
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
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    TransactionsModel? ptx = await _txController.getParent(tx);

    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: TransactionFormEdit(
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
          ),
        ),
      ),
    );
  }

  Future<void> _showTradeDialog(BuildContext context) async {
    TransactionsModel? ptx = await _txController.getParent(tx);
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: TransactionFormTrade(
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<bool>>(
      future: Future.wait([
        _txController.isTradable(tx),
        _txController.isClosable(tx),
        _txController.isDeletable(tx),
        _txController.isUpdatable(tx),
        _txController.isRefundable(tx),
        _txController.hasLeaf(tx),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final isTradable = snapshot.data![0];
        final isClosable = snapshot.data![1];
        final isDeletable = snapshot.data![2];
        final isUpdatable = snapshot.data![3];
        final isRefundable = snapshot.data![4];
        final hasLeaf = snapshot.data![5];

        return Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isUpdatable && tx.isActive && !hasLeaf)
              WidgetsButton(
                key: Key("edit-button-${tx.tid}"),
                icon: Icons.edit,
                tooltip: "Edit this transaction",
                padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
                iconSize: 16,
                minimumSize: const Size(34, 34),
                onPressed: (_) => _showEditDialog(context),
                evaluator: (s) {
                  _cryptosController.hasAny() ? s.normal() : s.disable();
                },
              ),

            if (isTradable)
              WidgetsButton(
                key: Key("trade-button-${tx.tid}"),
                icon: Icons.swap_horiz,
                initialState: WidgetsButtonActionState.action,
                tooltip: "Trade this transaction",
                padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
                iconSize: 18,
                minimumSize: const Size(34, 34),
                onPressed: (_) => _showTradeDialog(context),
                evaluator: (s) {
                  _cryptosController.hasAny() ? s.action() : s.disable();
                },
              ),

            if (isDeletable)
              WidgetsButton(
                key: Key("delete-button-${tx.tid}"),
                icon: Icons.delete,
                initialState: WidgetsButtonActionState.error,
                tooltip: "Delete this transaction",
                padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
                iconSize: 18,
                minimumSize: const Size(34, 34),
                onPressed: (_) => _showDeleteDialog(context),
              ),

            if (isRefundable)
              WidgetsButton(
                key: Key("refund-button-${tx.tid}"),
                icon: Icons.u_turn_left,
                initialState: WidgetsButtonActionState.error,
                tooltip: "Refund this transaction",
                padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
                iconSize: 18,
                minimumSize: const Size(34, 34),
                onPressed: (_) => _showRefundDialog(context),
              ),

            if (isClosable)
              WidgetsButton(
                key: Key("close-button-${tx.tid}"),
                icon: Icons.close,
                initialState: WidgetsButtonActionState.warning,
                tooltip: "Close this transaction",
                padding: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 2),
                iconSize: 18,
                minimumSize: const Size(34, 34),
                onPressed: (_) => _showCloseDialog(context),
              ),
          ],
        );
      },
    );
  }
}
