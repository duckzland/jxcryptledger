import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../mixins/rateable.dart';
import '../../../mixins/selectable_table.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/notify.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../model.dart';

enum TransactionsBatchActionMode { close, finalize, delete }

class TransactionsDialogsBatchAction extends StatefulWidget {
  final List<TransactionsModel>? transactions;
  final TransactionsBatchActionMode mode;
  final void Function(Object? error)? onSave;

  const TransactionsDialogsBatchAction({super.key, required this.onSave, this.transactions, required this.mode});

  @override
  State<TransactionsDialogsBatchAction> createState() => _TransactionsDialogsBatchActionState();
}

class _TransactionsDialogsBatchActionState extends State<TransactionsDialogsBatchAction>
    with MixinsSelectableTable, MixinsRateable<TransactionsDialogsBatchAction> {
  CryptosController get _cryptoController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  late List<TransactionsModel> txs;

  late String title;
  late String emptyMessage;
  late String buttonLabel;
  late String tooltip;
  late String confirmTitle;
  late String confirmMessage;
  late String successMessage;

  late WidgetsButtonActionState buttonActionState;

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
        tooltip = "Delete all selected transactions";
        buttonActionState = WidgetsButtonActionState.error;
        break;
    }

    for (final tx in txs) {
      selectableSetSelected(tx.uuid, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                if (txs.isNotEmpty) Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                if (txs.isNotEmpty)
                  WidgetsPanel(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 0, children: [_buildTable()]),
                  ),
                if (txs.isEmpty) Text(emptyMessage, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),

                WidgetsPanel(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    direction: Axis.horizontal,
                    runSpacing: 20,
                    spacing: 10,
                    runAlignment: WrapAlignment.center,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      WidgetsButton(label: 'Cancel', onPressed: (_) => Navigator.pop(context)),
                      if (txs.isNotEmpty)
                        WidgetsDialogsAlert(
                          label: buttonLabel,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          persistBg: true,
                          dialogTitle: confirmTitle,
                          dialogMessage: confirmMessage,
                          dialogCancelLabel: "Cancel",
                          dialogConfirmLabel: buttonLabel,
                          showMessage: false,
                          initialState: buttonActionState,
                          tooltip: tooltip,
                          evaluator: (s) {
                            if (selectableHasSelectedRows()) {
                              switch (widget.mode) {
                                case TransactionsBatchActionMode.close:
                                  s.warning();
                                  break;
                                case TransactionsBatchActionMode.finalize:
                                  s.warning();
                                  break;
                                case TransactionsBatchActionMode.delete:
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
      ),
    );
  }

  Widget _buildTable() {
    final rows = <Map<String, dynamic>>[];

    for (final tx in txs) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';

      rows.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': '${tx.srAmountText} $sourceSymbol → ${tx.balanceText} $resultSymbol',
        'tx': tx,
        'uuid': tx.uuid,
      });
    }

    return SizedBox(
      width: double.infinity,
      height: (rows.length * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 4,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
        child: DataTable2(
          headingCheckboxTheme: Theme.of(context).checkboxTheme,
          datarowCheckboxTheme: Theme.of(context).checkboxTheme,
          showHeadingCheckBox: true,
          showCheckboxColumn: true,
          minWidth: 800,
          columnSpacing: 12,
          horizontalMargin: 12,
          headingRowHeight: AppTheme.tableHeadingRowHeight,
          dataRowHeight: AppTheme.tableDataRowMinHeight,
          isHorizontalScrollBarVisible: false,
          columns: [
            DataColumn2(label: const Text('Date '), fixedWidth: 100),
            DataColumn2(label: const Text('Transactions '), size: ColumnSize.M),
          ],
          rows: [
            ...rows.map((r) {
              return DataRow(
                selected: selectableIsSelected(r['uuid']),
                onSelectChanged: (v) {
                  setState(() {
                    selectableSetSelected(r['uuid'], v!);
                  });
                },
                cells: [DataCell(Text(r['date'] ?? '')), DataCell(Text(r['transaction'] ?? ''))],
              );
            }),
          ],
        ),
      ),
    );
  }

  void _handleSave() async {
    final stxs = [...txs];

    final selectedTxIds = selectableGetSelectedRows();
    stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));

    if (stxs.isEmpty) return;

    for (final tx in stxs) {
      try {
        switch (widget.mode) {
          case TransactionsBatchActionMode.close:
            await _txController.closeLeaf(tx);
            break;
          case TransactionsBatchActionMode.finalize:
            await _txController.finalize(tx);
            break;
          case TransactionsBatchActionMode.delete:
            await _txController.remove(tx);
            break;
        }
        txs.remove(tx);
        selectableSetSelected(tx.uuid, false);
      } on ValidationException catch (e) {
        widget.onSave?.call(e);
        return;
      } catch (e) {
        widget.onSave?.call(e);
        return;
      }
    }

    if (txs.isEmpty && widget.onSave != null) {
      widget.onSave?.call(null);
    } else {
      widgetsNotifySuccess(successMessage);
      setState(() {});
    }
  }
}
