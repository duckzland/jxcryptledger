import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../core/locator.dart';
import '../../../mixins/rateable.dart';
import '../../../mixins/selectable_table.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/notify.dart';
import '../../../widgets/table/virtualized/single.dart';
import '../../../widgets/text/selectable.dart';
import '../../../widgets/with_tooltip.dart';
import '../../cryptos/controller.dart';
import '../batch/ops.dart';
import '../controller.dart';
import '../model.dart';

enum TransactionsBatchActionMode { close, finalize, delete, refund }

class TransactionsDialogsBatchAction extends StatefulWidget {
  final List<TransactionsModel>? transactions;
  final TransactionsBatchActionMode mode;
  final void Function(Object? error)? onSave;

  const TransactionsDialogsBatchAction({super.key, required this.onSave, this.transactions, required this.mode});

  @override
  State<TransactionsDialogsBatchAction> createState() => _TransactionsDialogsBatchActionState();
}

class _TransactionsDialogsBatchActionState extends State<TransactionsDialogsBatchAction>
    with
        MixinsState,
        MixinsTable<TransactionsDialogsBatchAction>,
        MixinsSelectableTable<TransactionsDialogsBatchAction>,
        MixinsRateable<TransactionsDialogsBatchAction> {
  CryptosController get _cryptoController => CoreLocator.getit<CryptosController>();
  TransactionsController get _txController => CoreLocator.getit<TransactionsController>();

  late List<TransactionsModel> txs;

  late String title;
  late String emptyMessage;
  late String buttonLabel;
  late String tooltip;
  late String confirmTitle;
  late String confirmMessage;
  late String successMessage;
  late String completedMessage;

  late WidgetsButtonActionState buttonActionState;

  bool _isProcessing = false;
  bool _isExiting = false;

  @override
  double get tableHeightOffset => 130;

  @override
  double get tableHeadingHeightOffset => 4;

  final ScrollController tableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    txs = List.from(widget.transactions ?? []);

    switch (widget.mode) {
      case TransactionsBatchActionMode.close:
        txs.removeWhere((tx) => !_txController.isClosable(tx));
        title = "Closing Transactions";
        emptyMessage = "No transactions to close";
        buttonLabel = "Close";
        confirmTitle = "Close Transactions";
        confirmMessage = "Are you sure you want to close the selected transactions?\nThis action cannot be undone.";
        successMessage = "Transactions closed successfully.";
        completedMessage = "Action closing transactions completed";
        tooltip = "Close all selected transactions";
        buttonActionState = WidgetsButtonActionState.warning;
        break;

      case TransactionsBatchActionMode.finalize:
        txs.removeWhere((tx) => !_txController.isFinalizable(tx));
        title = "Finalizing Transactions";
        emptyMessage = "No transactions to finalize";
        buttonLabel = "Finalize";
        confirmTitle = "Finalize Transactions";
        confirmMessage = "Are you sure you want to finalize the selected transactions?\nThis action cannot be undone.";
        successMessage = "Transactions finalized successfully.";
        completedMessage = "Action finalizing transactions completed";
        tooltip = "Finalize all selected transactions";
        buttonActionState = WidgetsButtonActionState.warning;
        break;

      case TransactionsBatchActionMode.delete:
        txs.removeWhere((tx) => !_txController.isDeletable(tx));
        title = "Deleting Transactions";
        emptyMessage = "No transactions to delete";
        buttonLabel = "Delete";
        confirmTitle = "Delete Transactions";
        confirmMessage = "Are you sure you want to delete the selected transactions?\nThis action cannot be undone.";
        successMessage = "Transactions deleted successfully.";
        completedMessage = "Action deleting transactions completed";
        tooltip = "Delete all selected transactions";
        buttonActionState = WidgetsButtonActionState.error;
        break;

      case TransactionsBatchActionMode.refund:
        txs.removeWhere((tx) => !_txController.isRefundable(tx));
        title = "Refunding Transactions";
        emptyMessage = "No transactions to refund";
        buttonLabel = "Refund";
        confirmTitle = "Refund Transactions";
        confirmMessage = "Are you sure you want to refund the selected transactions?\nThis action cannot be undone.";
        successMessage = "Transactions refunded successfully.";
        completedMessage = "Action refunding transactions completed";
        tooltip = "Refund all selected transactions";
        buttonActionState = WidgetsButtonActionState.error;
        break;
    }

    for (final tx in txs) {
      selectableSetSelected(tx.uuid, true);
    }

    tableBuildColumns();
    tablePopulateData();
  }

  @override
  void dispose() {
    tableScrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> tablePopulateData() {
    tableData = <Map<String, dynamic>>[];

    for (final tx in txs) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';

      tableData.add({
        'transaction': '${tx.srAmountText} $sourceSymbol → ${tx.rrAmountText} $resultSymbol',
        'balance': '${tx.balanceText} $resultSymbol',
        'tx': tx,
        'uuid': tx.uuid,
      });
    }
    return tableData;
  }

  List<DataColumn> tableBuildColumns() {
    if (tableColumns.isEmpty) {
      tableColumns = [
        DataColumn2(label: Text('Date '), fixedWidth: 100),
        DataColumn2(label: Text('Transactions '), size: ColumnSize.M),
        DataColumn2(label: Text('Balance '), size: ColumnSize.M),
      ];
    }
    return tableColumns;
  }

  DataRow tableBuildRow(Map<String, dynamic> row) {
    final tx = row['tx'] as TransactionsModel;

    return DataRow(
      selected: selectableIsSelected(row['uuid']),
      onSelectChanged: (v) {
        setState(() {
          selectableSetSelected(row['uuid'], v!);
        });
      },
      cells: [
        DataCell(WidgetsWithTooltip(WidgetsTextSelectable(tx.timestampAsFormattedDate), tx.noteText, tx.meta['accent_color'])),
        DataCell(WidgetsTextSelectable(row['transaction'] ?? '')),
        DataCell(WidgetsTextSelectable(row['balance'] ?? '')),
      ],
    );
  }

  Widget tableBuild() {
    final checkboxTheme = Theme.of(context).checkboxTheme;

    return SizedBox(
      width: double.infinity,
      height: tableCalculateAdjustedMaxHeight(),
      child: WidgetsTableVirtualizedSingle<Map<String, dynamic>>(
        controller: tableScrollController,
        data: tableData,
        rowBuilder: tableBuildRow,
        columnCount: tableColumns.length,
        childBuilder: (rows) => DataTable2(
          scrollController: tableScrollController,
          headingCheckboxTheme: checkboxTheme,
          datarowCheckboxTheme: checkboxTheme,
          showHeadingCheckBox: true,
          showCheckboxColumn: true,
          minWidth: 800,
          columnSpacing: 12,
          horizontalMargin: 12,
          headingRowHeight: tableHeadingHeight,
          dataRowHeight: tableRowHeight,
          isHorizontalScrollBarVisible: false,
          empty: Center(
            child: Text("No transactions available", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          onSelectAll: selectableOnSelectAll(() => tableData.map((r) => r['uuid'] as String)),
          columns: tableColumns,
          rows: rows,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isExiting) {
      return const SizedBox.shrink();
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 1200),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  if (txs.isNotEmpty) Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                  if (txs.isNotEmpty) tableBuild(),
                  if (txs.isEmpty) Text(emptyMessage, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),

                  Padding(
                    padding: const EdgeInsets.only(top: 15.0, bottom: 5),
                    child: Wrap(
                      direction: Axis.horizontal,
                      runSpacing: 20,
                      spacing: 10,
                      runAlignment: WrapAlignment.center,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        WidgetsButtonsAction(
                          label: 'Cancel',
                          onPressed: (_) => Navigator.pop(context),
                          evaluator: (s) {
                            _isProcessing ? s.disable() : s.normal();
                          },
                        ),
                        if (txs.isNotEmpty)
                          WidgetsDialogsAlert(
                            label: buttonLabel,
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                            filledMode: true,
                            dialogTitle: confirmTitle,
                            dialogMessage: confirmMessage,
                            dialogCancelLabel: "Cancel",
                            dialogConfirmLabel: buttonLabel,
                            showMessage: false,
                            initialState: buttonActionState,
                            tooltip: tooltip,
                            evaluator: (s) {
                              if (_isProcessing) {
                                s.progress();
                                return;
                              }
                              if (selectableHasSelectedRows()) {
                                switch (widget.mode) {
                                  case TransactionsBatchActionMode.close:
                                  case TransactionsBatchActionMode.finalize:
                                    s.warning();
                                    break;
                                  case TransactionsBatchActionMode.delete:
                                  case TransactionsBatchActionMode.refund:
                                    s.error();
                                    break;
                                }
                              } else {
                                s.disable();
                              }
                            },
                            actionCompleteCallback: _handleSave,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isProcessing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    final sids = selectableGetSelectedRows();
    final stxs = txs.where((tx) => sids.contains(tx.uuid)).toList();
    if (stxs.isEmpty) return;

    setState(() => _isProcessing = true);

    final ops = TransactionsBatchOps();
    for (final tx in stxs) {
      switch (widget.mode) {
        case TransactionsBatchActionMode.close:
          ops.close(tx, tag: tx);
        case TransactionsBatchActionMode.finalize:
          ops.finalize(tx, tag: tx);
        case TransactionsBatchActionMode.delete:
          ops.remove(tx, tag: tx);
        case TransactionsBatchActionMode.refund:
          ops.refund(tx, tag: tx);
      }
    }

    await _txController.batchOperation(ops);

    for (final tx in ops.succeededTags<TransactionsModel>()) {
      txs.remove(tx);
      selectableSetSelected(tx.uuid, false);
    }

    if (ops.isAllSuccess) {
      txs.isNotEmpty ? widgetsNotifySuccess(successMessage) : widget.onSave?.call(null);
    } else {
      widget.onSave?.call(
        ops.toException(
          AppErrorCode.batchOpsFailed,
          'Unable to ${widget.mode.name} the selected transactions. Please check their status and try again.',
        ),
      );
    }

    setState(() {
      _isExiting = txs.isEmpty;
      _isProcessing = false;
      tablePopulateData();
    });
  }
}
