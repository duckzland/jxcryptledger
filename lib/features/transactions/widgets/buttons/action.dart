import 'package:flutter/material.dart';

import '../../../../mixins/actionable.dart';
import '../../../../widgets/buttons/action.dart';
import '../../../../widgets/buttons/dropdown.dart';
import '../../../../widgets/dialogs/alert.dart';
import '../../../../widgets/dialogs/show_form.dart';
import '../../../cryptos/controller.dart';
import '../../dialogs/balance_snapshot.dart';
import '../../forms/edit.dart';
import '../../forms/trade.dart';
import '../../model.dart';
import '../../controller.dart';

class TransactionsWidgetsButtonsAction extends StatelessWidget with MixinsActionable {
  final TransactionsModel tx;
  final CryptosController cryptosController;
  final TransactionsController txController;
  final void Function() onAction;
  final void Function()? onExit;

  final bool isTradable;
  final bool isClosable;
  final bool isDeletable;
  final bool isUpdatable;
  final bool isRefundable;
  final bool isFinalizable;

  final bool hasLeaf;
  final bool hasTradeableLeaf;

  final bool? allowBalanceSnapshot;

  final BuildContext parentContext;

  const TransactionsWidgetsButtonsAction({
    super.key,
    required this.parentContext,
    required this.tx,
    required this.txController,
    required this.cryptosController,
    required this.onAction,
    required this.isTradable,
    required this.isClosable,
    required this.isDeletable,
    required this.isUpdatable,
    required this.isRefundable,
    required this.isFinalizable,
    required this.hasLeaf,
    required this.hasTradeableLeaf,
    this.onExit,
    this.allowBalanceSnapshot = false,
  });

  @override
  Widget build(BuildContext context) {
    final sourceSymbol = cryptosController.getSymbol(tx.srId) ?? "";
    final targetSymbol = cryptosController.getSymbol(tx.rrId) ?? "";

    final btnSize = const Size(34, 34);
    final btnPadding = const EdgeInsets.only(left: 4, right: 4, top: 4, bottom: 4);
    final iconSize = 16.0;

    final List<Widget> buttons = [];
    final List<WidgetsButtonActionState> states = [];

    if (allowBalanceSnapshot == true && tx.isRoot && hasTradeableLeaf) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: Key("balance-snapshot-button-${tx.tid}"),
          icon: Icons.insights,
          label: "Show Balance",
          tooltip: "Show balance snapshots of this transaction",
          padding: btnPadding,
          iconSize: iconSize,
          minimumSize: btnSize,
          evaluator: _evaluatorShowBalance,
          buildForm: _formShowBalance,
        ),
      );
      states.add(WidgetsButtonActionState.normal);
    }

    if (isUpdatable && tx.isActive && !hasLeaf) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: Key("edit-button-${tx.tid}"),
          icon: Icons.edit,
          label: "Edit",
          tooltip: "Edit this transaction",
          padding: btnPadding,
          iconSize: iconSize,
          minimumSize: btnSize,
          evaluator: _evaluatorEditTx,
          buildForm: _formEditTx,
        ),
      );
      states.add(WidgetsButtonActionState.normal);
    }

    if (isTradable) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: Key("trade-button-${tx.tid}"),
          icon: Icons.swap_vert,
          label: "Trade",
          initialState: WidgetsButtonActionState.action,
          tooltip: "Trade this transaction",
          padding: btnPadding,
          iconSize: iconSize,
          minimumSize: btnSize,
          evaluator: _evaluatorTradeTx,
          buildForm: _formTradeTx,
        ),
      );
      states.add(WidgetsButtonActionState.action);
    }

    if (isDeletable) {
      buttons.add(
        WidgetsDialogsAlert(
          key: Key("delete-button-${tx.tid}"),
          icon: Icons.delete,
          label: "Delete",
          initialState: WidgetsButtonActionState.error,
          tooltip: "Delete this transaction",
          padding: btnPadding,
          iconSize: iconSize,
          minimumSize: btnSize,
          dialogTitle: "Delete Transaction",
          dialogMessage:
              "This will delete this transaction and all of its history.\n"
              "This action cannot be undone.",
          dialogConfirmLabel: "Delete",
          actionData: tx,
          actionCallback: _actionDelete,
          actionCompleteCallback: onAction,
          actionSuccessMessage: "${tx.srAmountText} $sourceSymbol - ${tx.balanceText} $targetSymbol transaction deleted.",
        ),
      );
      states.add(WidgetsButtonActionState.error);
    }

    if (isRefundable) {
      buttons.add(
        WidgetsDialogsAlert(
          key: Key("refund-button-${tx.tid}"),
          icon: Icons.u_turn_left,
          label: "Refund",
          initialState: WidgetsButtonActionState.error,
          tooltip: "Refund this transaction",
          padding: btnPadding,
          iconSize: iconSize,
          minimumSize: btnSize,
          dialogTitle: "Refund Transaction",
          dialogMessage:
              "This will cancel this transaction and refund the balance back to its parent transaction.\n"
              "This action cannot be undone.",
          dialogConfirmLabel: "Refund",
          actionData: tx,
          actionCallback: _actionRefund,
          actionCompleteCallback: onAction,
          actionSuccessMessage: "${tx.srAmountText} $sourceSymbol - ${tx.balanceText} $targetSymbol transaction deleted.",
        ),
      );
      states.add(WidgetsButtonActionState.error);
    }

    if (isClosable) {
      buttons.add(
        WidgetsDialogsAlert(
          key: Key("close-button-${tx.tid}"),
          icon: Icons.close,
          label: "Close",
          initialState: WidgetsButtonActionState.warning,
          tooltip: "Close this transaction",
          padding: btnPadding,
          iconSize: iconSize,
          minimumSize: btnSize,
          dialogTitle: "Close Transaction",
          dialogMessage: "Are you sure you want to close this transaction?",
          dialogConfirmLabel: "Close",
          actionData: tx,
          actionCallback: txController.closeLeaf,
          actionCompleteCallback: onAction,
          actionSuccessMessage: "${tx.srAmountText} - ${tx.balanceText} transaction closed.",
        ),
      );
      states.add(WidgetsButtonActionState.warning);
    }

    if (isFinalizable) {
      buttons.add(
        WidgetsDialogsAlert(
          key: Key("finalize-button-${tx.tid}"),
          icon: Icons.close_fullscreen,
          label: "Finalize",
          initialState: WidgetsButtonActionState.warning,
          tooltip: "Finalize this transaction",
          padding: btnPadding,
          iconSize: iconSize,
          minimumSize: btnSize,
          dialogTitle: "Finalize Transaction",
          dialogMessage: "Are you sure you want to finalize this transaction?",
          dialogConfirmLabel: "finalize",
          actionData: tx,
          actionCallback: txController.finalize,
          actionCompleteCallback: onAction,
          actionSuccessMessage: "${tx.srAmountText} - ${tx.balanceText} transaction finalized.",
        ),
      );
      states.add(WidgetsButtonActionState.warning);
    }

    return WidgetsButtonsDropdown(
      dotStates: states,
      maxVisible: 2,
      iconWidth: 28,
      iconHeight: 28,
      menuWidth: 100,
      menuAlignRight: true,
      children: buttons,
    );
  }

  Future<void> _actionRefund(TransactionsModel tx) async {
    if (onExit != null) {
      onExit?.call();
      await Future.delayed(const Duration(milliseconds: 150));
    }
    await txController.removeLeaf(tx);
  }

  Future<void> _actionDelete(TransactionsModel tx) async {
    if (onExit != null) {
      onExit?.call();
      await Future.delayed(const Duration(milliseconds: 150));
    }
    await txController.removeRoot(tx);
  }

  void _evaluatorShowBalance(WidgetsButtonsActionState s) {
    !cryptosController.isEmpty() ? s.normal() : s.disable();
  }

  void _evaluatorEditTx(WidgetsButtonsActionState s) {
    !cryptosController.isEmpty() ? s.normal() : s.disable();
  }

  void _evaluatorTradeTx(WidgetsButtonsActionState s) {
    !cryptosController.isEmpty() ? s.action() : s.disable();
  }

  Widget _formShowBalance(BuildContext dialogContext) {
    final ptx = txController.getParent(tx);
    return TransactionsDialogsBalanceSnapshots(initialData: tx, parent: ptx);
  }

  Widget _formEditTx(BuildContext dialogContext) {
    return TransactionFormEdit(
      initialData: tx,
      parent: txController.getParent(tx),
      onSave: (e, stx) => actionableFormSave<TransactionsModel>(
        parentContext,
        dialogContext: dialogContext,
        onComplete: onAction,
        successMessage: "${tx.srAmountText} - ${tx.balanceText} transaction updated.",
        error: e,
      ),
    );
  }

  Widget _formTradeTx(BuildContext dialogContext) {
    return TransactionFormTrade(
      initialData: tx,
      parent: txController.getParent(tx),
      onSave: (e, stx) => actionableFormSave<TransactionsModel>(
        parentContext,
        dialogContext: dialogContext,
        onComplete: onAction,
        successMessage: "New trading transaction created.",
        error: e,
      ),
    );
  }
}
