import 'package:flutter/material.dart';

import '../../../mixins/actionable.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialogs/show_form.dart';
import '../dialogs/batch_action.dart';
import '../dialogs/batch_trade.dart';
import '../model.dart';

class TransactionsWidgetsBatchButtons extends StatelessWidget with MixinsActionable {
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

  final void Function(WidgetsButtonState) onToggleShow;

  const TransactionsWidgetsBatchButtons({
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
    final btnPadding = const EdgeInsets.all(0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (isActive)
          WidgetsDialogsShowForm(
            key: const Key("trade-multiple-button"),
            icon: Icons.swap_vert,
            tooltip: "Show batch trade action for the selected transactions",
            padding: btnPadding,
            iconSize: btnIconSize,
            minimumSize: btnSize,
            buildForm: (dialogContext) {
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
            },
          ),

        if (isDeletable)
          WidgetsDialogsShowForm(
            key: const Key("delete-multiple-button"),
            icon: Icons.delete,
            tooltip: "Delete all transactions",
            initialState: WidgetsButtonActionState.error,
            evaluator: (s) {
              if (!isDeletable) {
                s.disable();
              } else {
                s.error();
              }
            },
            padding: btnPadding,
            iconSize: btnIconSize,
            minimumSize: btnSize,
            buildForm: (dialogContext) {
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
            },
          ),

        if (isRefundable)
          WidgetsDialogsShowForm(
            key: const Key("refund-multiple-button"),
            icon: Icons.u_turn_left,
            tooltip: "Refund all refundable transactions found in this group",
            initialState: WidgetsButtonActionState.error,
            evaluator: (s) {
              if (!isRefundable) {
                s.disable();
              } else {
                s.error();
              }
            },
            padding: btnPadding,
            iconSize: btnIconSize,
            minimumSize: btnSize,
            buildForm: (dialogContext) {
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
            },
          ),

        if (isClosable)
          WidgetsDialogsShowForm(
            key: const Key("close-multiple-button"),
            icon: Icons.close,
            tooltip: "Close all closable transactions found in this group",
            initialState: WidgetsButtonActionState.warning,
            evaluator: (s) {
              if (!isClosable) {
                s.disable();
              } else {
                s.warning();
              }
            },
            padding: btnPadding,
            iconSize: btnIconSize,
            minimumSize: btnSize,
            buildForm: (dialogContext) {
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
            },
          ),

        if (isFinalizable)
          WidgetsDialogsShowForm(
            key: const Key("finalize-multiple-button"),
            icon: Icons.close_fullscreen,
            tooltip: "Finalize all finalizable transactions found in this group",
            initialState: WidgetsButtonActionState.warning,
            evaluator: (s) {
              if (!isFinalizable) {
                s.disable();
              } else {
                s.warning();
              }
            },
            padding: btnPadding,
            iconSize: btnIconSize,
            minimumSize: btnSize,
            buildForm: (dialogContext) {
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
            },
          ),

        WidgetsButton(
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
}
