import 'package:flutter/material.dart';

import '../../../../core/runtime/locator.dart';
import '../../../../mixins/actionable.dart';
import '../../../../widgets/buttons/action.dart';
import '../../../../widgets/buttons/dropdown.dart';
import '../../../../widgets/dialogs/show_form.dart';
import '../../../watchboard/panels/controller.dart';
import '../../../watchboard/panels/form.dart';
import '../../../watchboard/panels/model.dart';
import '../../../watchers/controller.dart';
import '../../../watchers/form.dart';
import '../../../watchers/model.dart';
import '../../dialogs/batch_action.dart';
import '../../dialogs/batch_notes.dart';
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
  final bool isUpdatable;

  final double menuWidth;

  final double? rate;
  final double? balance;

  final String? linkableKey;

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
    required this.isUpdatable,
    required this.onToggleShow,
    this.menuWidth = 140,
    this.rate,
    this.balance,
    this.linkableKey,
  });

  bool get isLinkable => srid != rrid;
  bool get isActive => txs.any((tx) => tx.isActive || tx.isPartial);
  bool get hasSelectedRows => selectedRows.isNotEmpty;

  WatchersModel? get linkedWatcher => wxController.getLinked("$linkableKey-$srid-$rrid");
  PanelsModel? get linkedPanel => pxController.getLinked("$linkableKey-$srid-$rrid");

  WatchersController get wxController => locator<WatchersController>();
  PanelsController get pxController => locator<PanelsController>();

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
    }

    if (isUpdatable) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("notes-multiple-button"),
          icon: Icons.note_add,
          label: "Notes & Accents",
          tooltip: "Show batch transactions notes and accent updater",
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          buildForm: _formNotesTx,
        ),
      );
    }

    if (isDeletable) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("delete-multiple-button"),
          icon: Icons.delete,
          label: "Delete",
          tooltip: "Delete all transactions",
          initialState: WidgetsButtonActionState.error,
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          buildForm: _formDeleteTx,
        ),
      );
    }

    if (isRefundable) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("refund-multiple-button"),
          icon: Icons.u_turn_left,
          label: "Refund",
          tooltip: "Refund all refundable transactions found in this group",
          initialState: WidgetsButtonActionState.error,
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          buildForm: _formRefundTx,
        ),
      );
    }

    if (isClosable) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("close-multiple-button"),
          icon: Icons.close,
          label: "Close",
          tooltip: "Close all closable transactions found in this group",
          initialState: WidgetsButtonActionState.warning,
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          buildForm: _formCloseTx,
        ),
      );
    }

    if (isFinalizable) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("finalize-multiple-button"),
          icon: Icons.close_fullscreen,
          label: "Finalize",
          tooltip: "Finalize all finalizable transactions found in this group",
          initialState: WidgetsButtonActionState.warning,
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          buildForm: _formFinalizeTx,
        ),
      );
    }

    if (isLinkable && balance != null && balance! > 0) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("add-watchboard-button"),
          icon: Icons.candlestick_chart_outlined,
          label: "Watchboard",
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          tooltip: "Manage linked watchboard",
          initialState: WidgetsButtonActionState.action,
          filledMode: true,
          evaluator: _evaluatorWatchboard,
          buildForm: _formWatchboard,
        ),
      );
    }

    if (isLinkable && rate != null && linkableKey != null) {
      buttons.add(
        WidgetsDialogsShowForm(
          key: const Key("add-watcher-button"),
          icon: Icons.add_alarm,
          label: "Rate Watcher",
          padding: btnPadding,
          iconSize: btnIconSize,
          minimumSize: btnSize,
          tooltip: "Manage linked rate watcher",
          initialState: WidgetsButtonActionState.action,
          filledMode: true,
          evaluator: _evaluatorWatcher,
          buildForm: _formWatcher,
        ),
      );
    }

    return Row(
      spacing: 6,
      children: [
        WidgetsButtonsDropdown(
          key: const Key("batch-buttons"),
          dotStates: states,
          maxVisible: 1,
          iconWidth: 34,
          iconHeight: 34,
          menuWidth: menuWidth,
          menuAlignRight: true,
          listener: Listenable.merge([pxController, wxController]),
          dotEvaluator: _evaluatorDropdown,
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

  List<WidgetsButtonActionState> _evaluatorDropdown(MenuController controller) {
    return [
      if (isActive) WidgetsButtonActionState.action,
      if (isUpdatable) WidgetsButtonActionState.action,
      if (isDeletable) WidgetsButtonActionState.error,
      if (isRefundable) WidgetsButtonActionState.error,
      if (isClosable) WidgetsButtonActionState.warning,
      if (isFinalizable) WidgetsButtonActionState.warning,
      if (isLinkable && balance != null && balance! > 0)
        linkedPanel == null
            ? (controller.isOpen ? WidgetsButtonActionState.reversed : WidgetsButtonActionState.muted)
            : WidgetsButtonActionState.action,
      if (isLinkable && rate != null && linkableKey != null)
        linkedWatcher == null
            ? (controller.isOpen ? WidgetsButtonActionState.reversed : WidgetsButtonActionState.muted)
            : (linkedWatcher!.isSpent ? WidgetsButtonActionState.error : WidgetsButtonActionState.action),
    ];
  }

  void _evaluatorWatchboard(WidgetsButtonsActionState s) {
    final linkedPanel = pxController.getLinked("$linkableKey-$srid-$rrid");
    if (s.widget.filledMode) {
      if (linkedPanel == null) {
        s.normal();
      } else {
        s.action();
      }
    }
  }

  void _evaluatorWatcher(WidgetsButtonsActionState s) {
    final linkedWatcher = wxController.getLinked("$linkableKey-$srid-$rrid");
    if (s.widget.filledMode) {
      if (linkedWatcher == null) {
        s.normal();
      } else {
        linkedWatcher.isSpent ? s.error() : s.action();
      }
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

  Widget _formNotesTx(BuildContext dialogContext) {
    final stxs = [...txs];

    if (hasSelectedRows) {
      final selectedTxIds = selectedRows;
      stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));
    }

    return TransactionsDialogsBatchNotes(
      transactions: stxs,
      onSave: (e) => actionableFormSave<TransactionsModel>(
        parentContext,
        dialogContext: dialogContext,
        successMessage: "Update completed successfully.",
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

  Widget _formWatchboard(BuildContext dialogContext) {
    return PanelsForm(
      initialData: linkedPanel,
      initialSrId: linkedPanel == null ? srid : null,
      initialRrId: linkedPanel == null ? rrid : null,
      initialSrAmount: linkedPanel == null ? balance : null,
      linkedToTx: "$linkableKey-$srid-$rrid",
      onSave: (e) => actionableFormSave<PanelsModel>(
        parentContext,
        dialogContext: dialogContext,
        successMessage: linkedPanel == null ? "Created watchboard entry." : "Watchboard entry updated",
        error: e,
      ),
    );
  }

  Widget _formWatcher(BuildContext dialogContext) {
    return WatchersForm(
      initialData: linkedWatcher,
      initialSrId: linkedWatcher == null ? srid : null,
      initialRrId: linkedWatcher == null ? rrid : null,
      initialRate: linkedWatcher == null ? rate : null,
      linkedToTx: "$linkableKey-$srid-$rrid",
      onSave: (e) => actionableFormSave<WatchersModel>(
        parentContext,
        dialogContext: dialogContext,
        successMessage: linkedWatcher == null ? "Created rate watcher." : "Rate watcher updated",
        error: e,
      ),
    );
  }
}
