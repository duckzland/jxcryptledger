import 'package:flutter/material.dart';

import '../../app/exceptions.dart';
import '../../core/locator.dart';
import '../../widgets/button.dart';
import '../../widgets/notify.dart';
import '../cryptos/repository.dart';
import 'controller.dart';
import 'form.dart';
import 'forms/edit.dart';
import 'forms/trade.dart';
import 'model.dart';

enum TransactionsButtonActionMode { edit, trade, close, delete }

class TransactionsButtons extends StatelessWidget {
  final TransactionsModel tx;
  final void Function() onAction;
  final CryptosRepository _cryptosRepo = locator<CryptosRepository>();

  TransactionsController get _txController => locator<TransactionsController>();

  TransactionsButtons({super.key, required this.tx, required this.onAction});

  Future<void> _showDeleteDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: AlertDialog(
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
                initialState: WidgetsButtonActionState.error,
                onPressed: (_) async {
                  try {
                    await _txController.removeRoot(tx);

                    Navigator.pop(dialogContext);
                    onAction();

                    widgetsNotifySuccess("${tx.srAmountText} - ${tx.balanceText} transaction deleted.");
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
            title: const Text("Close Transaction"),
            content: const Text("Are you sure you want to close this transaction?"),
            actions: [
              WidgetButton(label: 'Cancel', onPressed: (_) => Navigator.pop(dialogContext)),
              const SizedBox(width: 12),
              WidgetButton(
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
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final isTradable = snapshot.data![0];
        final isClosable = snapshot.data![1];
        final isDeletable = snapshot.data![2];
        final isUpdatable = snapshot.data![3];

        return Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isUpdatable && tx.isActive)
              WidgetButton(
                key: Key("edit-button-${tx.tid}"),
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

            if (isTradable)
              WidgetButton(
                key: Key("trade-button-${tx.tid}"),
                icon: Icons.swap_horiz,
                initialState: WidgetsButtonActionState.action,
                tooltip: "Trade",
                padding: const EdgeInsets.all(8),
                iconSize: 18,
                minimumSize: const Size(36, 36),
                onPressed: (_) => _showTradeDialog(context),
                evaluator: (s) {
                  _cryptosRepo.hasAny() ? s.action() : s.disable();
                },
              ),

            if (isDeletable)
              WidgetButton(
                key: Key("delete-button-${tx.tid}"),
                icon: Icons.delete,
                initialState: WidgetsButtonActionState.error,
                tooltip: "Delete",
                padding: const EdgeInsets.all(8),
                iconSize: 18,
                minimumSize: const Size(36, 36),
                onPressed: (_) => _showDeleteDialog(context),
              ),

            if (isClosable)
              WidgetButton(
                key: Key("close-button-${tx.tid}"),
                icon: Icons.close,
                initialState: WidgetsButtonActionState.warning,
                tooltip: "Close",
                padding: const EdgeInsets.all(8),
                iconSize: 18,
                minimumSize: const Size(36, 36),
                onPressed: (_) => _showCloseDialog(context),
              ),
          ],
        );
      },
    );
  }
}
