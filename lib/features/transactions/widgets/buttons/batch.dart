import 'package:flutter/material.dart';

import '../../../../mixins/actionable.dart';
import '../../../../widgets/buttons/action.dart';
import '../../../../widgets/buttons/dropdown.dart';
import '../../../../widgets/dialogs/show_form.dart';
import '../../dialogs/batch_action.dart';
import '../../dialogs/batch_trade.dart';
import '../../model.dart';

class TransactionsWidgetsButtonsBatch extends StatelessWidget with MixinsActionable {
  final int srid;
  final int rrid;
  final BuildContext parentContext;

  final List<TransactionsModel> txs;
  final List<String> selectedRows;

  final bool isOpen;
  final bool isDeletable;
  final bool isClosable;
  final bool isFinalizable;
  final bool isRefundable;

  final void Function(WidgetsButtonsActionState) onToggleShow;

  const TransactionsWidgetsButtonsBatch({
    super.key,
    required this.parentContext,
    required this.srid,
    required this.rrid,
    required this.txs,
    required this.selectedRows,
    required this.isOpen,
    required this.isDeletable,
    required this.isClosable,
    required this.isFinalizable,
    required this.isRefundable,
    required this.onToggleShow,
  });

  bool get isActive => txs.any((tx) => tx.isActive || tx.isPartial);
  bool get hasSelectedRows => selectedRows.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final btnIconSize = 18.0;
    final btnSize = const Size(40, 40);
    final btnPadding = const EdgeInsets.only(left: 6, right: 6, top: 6, bottom: 6);

    final List<Widget> buttons = [];
    final List<WidgetsButtonActionState> states = [];

    if (isActive) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("trade-multiple-button"),
          icon: Icons.swap_vert,
          label: "Trade",
          tooltip: "Show batch trade action for the selected transactions",
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          buildForm: _formTradeTx,
        ),
      );
      states.add(WidgetsButtonActionState.action);
    }

    if (isDeletable) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("delete-multiple-button"),
          icon: Icons.delete,
          label: "Delete",
          tooltip: "Delete all transactions",
          initialState: WidgetsButtonActionState.error,
          evaluator: _evaluatorDeleteTx,
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          buildForm: _formDeleteTx,
        ),
      );
      states.add(WidgetsButtonActionState.error);
    }

    if (isRefundable) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("refund-multiple-button"),
          icon: Icons.u_turn_left,
          label: "Refund",
          tooltip: "Refund all refundable transactions found in this group",
          initialState: WidgetsButtonActionState.error,
          evaluator: _evaluatorRefundTx,
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          buildForm: _formRefundTx,
        ),
      );
      states.add(WidgetsButtonActionState.error);
    }

    if (isClosable) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("close-multiple-button"),
          icon: Icons.close,
          label: "Close",
          tooltip: "Close all closable transactions found in this group",
          initialState: WidgetsButtonActionState.warning,
          evaluator: _evaluatorCloseTx,
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          buildForm: _formCloseTx,
        ),
      );
      states.add(WidgetsButtonActionState.warning);
    }

    if (isFinalizable) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("finalize-multiple-button"),
          icon: Icons.close_fullscreen,
          label: "Finalize",
          tooltip: "Finalize all finalizable transactions found in this group",
          initialState: WidgetsButtonActionState.warning,
          evaluator: _evaluatorFinalizeTx,
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          buildForm: _formFinalizeTx,
        ),
      );
      states.add(WidgetsButtonActionState.warning);
    }

    return Row(
      spacing: 6,
      children: [
        WidgetsButtonsDropdown(
          dotStates: states,
          maxVisible: 1,
          iconWidth: 34,
          iconHeight: 34,
          menuWidth: 100,
          menuAlignRight: true,
          children: buttons,
        ),
        WidgetsButtonsAction(
          key: const Key("toggle-show-button"),
          icon: isOpen ? Icons.expand_less : Icons.expand_more,
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          tooltip: isOpen ? "Hide table" : "Show table",
          onPressed: onToggleShow,
        ),
      ],
    );
  }

  void _evaluatorDeleteTx(WidgetsButtonsActionState s) {
    if (!isDeletable) {
      s.disable();
    } else {
      s.error();
    }
  }

  void _evaluatorRefundTx(WidgetsButtonsActionState s) {
    if (!isRefundable) {
      s.disable();
    } else {
      s.error();
    }
  }

  void _evaluatorCloseTx(WidgetsButtonsActionState s) {
    if (!isClosable) {
      s.disable();
    } else {
      s.warning();
    }
  }

  void _evaluatorFinalizeTx(WidgetsButtonsActionState s) {
    if (!isFinalizable) {
      s.disable();
    } else {
      s.warning();
    }
  }

  Widget _formTradeTx(BuildContext dialogContext) {
    final stxs = [...txs];

    if (hasSelectedRows) {
      final selectedTxIds = selectedRows;
      stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));
    }

    return TransactionsDialogsBatchTrade(
      srId: rrid,
      transactions: stxs,
      onSave: (e) => actionableFormSave<TransactionsModel>(
        parentContext,
        dialogContext: dialogContext,
        successMessage: "Trade completed successfully.",
        error: e,
      ),
    );
  }

  Widget _formDeleteTx(BuildContext dialogContext) {
    return TransactionsDialogsBatchAction(
      transactions: txs,
      mode: TransactionsBatchActionMode.delete,
      onSave: (e) => actionableFormSave<TransactionsModel>(
        parentContext,
        dialogContext: dialogContext,
        successMessage: "All transactions deleted.",
        error: e,
      ),
    );
  }

  Widget _formRefundTx(BuildContext dialogContext) {
    return TransactionsDialogsBatchAction(
      transactions: txs,
      mode: TransactionsBatchActionMode.refund,
      onSave: (e) => actionableFormSave<TransactionsModel>(
        parentContext,
        dialogContext: dialogContext,
        successMessage: "Transactions refunded successfully.",
        error: e,
      ),
    );
  }

  Widget _formCloseTx(BuildContext dialogContext) {
    return TransactionsDialogsBatchAction(
      transactions: txs,
      mode: TransactionsBatchActionMode.close,
      onSave: (e) => actionableFormSave<TransactionsModel>(
        parentContext,
        dialogContext: dialogContext,
        successMessage: "Transactions closed successfully.",
        error: e,
      ),
    );
  }

  Widget _formFinalizeTx(BuildContext dialogContext) {
    return TransactionsDialogsBatchAction(
      transactions: txs,
      mode: TransactionsBatchActionMode.finalize,
      onSave: (e) => actionableFormSave<TransactionsModel>(
        parentContext,
        dialogContext: dialogContext,
        successMessage: "All transactions finalized.",
        error: e,
      ),
    );
  }
}
