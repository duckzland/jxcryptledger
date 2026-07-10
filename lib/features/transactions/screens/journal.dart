import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../core/runtime/locator.dart';
import '../../../core/scrollto.dart';
import '../../../mixins/scrollto_table.dart';
import '../../../mixins/sortable_table.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/panel.dart';
import '../../../widgets/with_tooltip.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../dialogs/details.dart';
import '../mixins/flags.dart';
import '../widgets/buttons.dart';
import '../model.dart';

class TransactionsJournalView extends StatefulWidget {
  final List<TransactionsModel> transactions;
  final Map<String, Map<String, bool>> txsFlags;
  final int filterMode;
  final VoidCallback onStatusChanged;

  const TransactionsJournalView({
    super.key,
    required this.transactions,
    required this.txsFlags,
    required this.filterMode,
    required this.onStatusChanged,
  });

  @override
  State<TransactionsJournalView> createState() => _TransactionsJournalViewState();
}

class _TransactionsJournalViewState extends State<TransactionsJournalView>
    with
        MixinsState,
        MixinsTable,
        AutomaticKeepAliveClientMixin,
        MixinsSortableTable<TransactionsJournalView>,
        MixinsScrollToTable<TransactionsJournalView, TransactionsModel>,
        TransactionsMixinsFlags {
  CryptosController get _cryptosController => locator<CryptosController>();

  int _filterMode = 0;

  @override
  String get sortableKey => "tx-group-journal";

  @override
  final scrollToUtil = ScrollTo('tx-group-offset-journal');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _filterMode = widget.filterMode;

    txController = locator<TransactionsController>();

    txs = widget.transactions;
    txsFlags = widget.txsFlags;
    txs = _processTx();

    sortableSorters = {
      0: (col, asc) => sortableOnSort((d) => d['_timestamp'] as int, col, asc),
      1: (col, asc) => sortableOnSort((d) => (d['_balanceSymbol'] as String, d['_balanceValue'] as double), col, asc),
      2: (col, asc) => sortableOnSort((d) => (d['_sourceSymbol'] as String, d['_sourceValue'] as double), col, asc),
      3: (col, asc) => sortableOnSort((d) => (d['_resultSymbol'] as String, d['_resultValue'] as double), col, asc),
      5: (col, asc) => sortableOnSort((d) => d['status'] as String, col, asc),
    };

    rows = _buildRows();
    sortableApplySorting();
  }

  @override
  void dispose() {
    scrollToUtil.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsJournalView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (widget.filterMode != oldWidget.filterMode) {
      setState(() {
        _filterMode = widget.filterMode;
        txs = widget.transactions;
        txsFlags = widget.txsFlags;
        txs = _processTx();
        rows = _buildRows();
      });
      return;
    }

    if (txController.isBothEqualGroup(oldWidget.transactions, widget.transactions)) {
      return;
    }

    setState(() {
      final ntx = txController.findNew(txs);
      txs = widget.transactions;
      txsFlags = widget.txsFlags;
      rows = _buildRows();
      sortableApplySorting();
      if (ntx != null) {
        scrollToTableNewRow(ntx);
      }
    });
  }

  List<Map<String, dynamic>> _buildRows() {
    final rx = <Map<String, dynamic>>[];

    for (final tx in txs) {
      final sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptosController.getSymbol(tx.rrId) ?? 'Unknown Coin';

      rx.add({
        'date': tx.timestampAsFormattedDate,
        'balance': '${tx.balanceText} $resultSymbol',
        'source': tx.isCapital ? 'Capital' : '${tx.srAmountText} $sourceSymbol',
        'result': tx.isCapital ? ' - ' : '${tx.rrAmountText} $resultSymbol',
        'rate': tx.isCapital ? ' - ' : '${tx.rateText} $resultSymbol/$sourceSymbol',
        'status': tx.statusText,
        'tx': tx,
        'note': tx.noteText,
        'uuid': tx.uuid,

        '_timestamp': tx.sanitizedTimestamp,
        '_balanceValue': tx.rrAmount,
        '_balanceSymbol': resultSymbol,
        '_sourceValue': tx.srAmount,
        '_sourceSymbol': sourceSymbol,
        '_resultValue': tx.rrAmount,
        '_resultSymbol': resultSymbol,
      });
    }
    return rx;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return WidgetsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
              child: DataTable2(
                key: const Key("table-journal"),
                scrollController: scrollToUtil.controller,
                minWidth: 1200,
                columnSpacing: 12,
                horizontalMargin: 12,
                headingRowHeight: tableHeadingHeight,
                dataRowHeight: tableRowHeight,
                showCheckboxColumn: false,
                sortColumnIndex: sortableColumnIndex,
                sortAscending: sortableAscending,
                isHorizontalScrollBarVisible: false,
                empty: const Center(
                  child: Text("No transactions available", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                columns: [
                  DataColumn2(label: const Text('Date'), fixedWidth: 100, onSort: sortableSorters[0]),
                  DataColumn2(label: const Text('Balance'), size: ColumnSize.M, onSort: sortableSorters[1]),
                  DataColumn2(label: const Text('From'), size: ColumnSize.M, onSort: sortableSorters[2]),
                  DataColumn2(label: const Text('To'), size: ColumnSize.M, onSort: sortableSorters[3]),
                  const DataColumn2(label: Text('Rate'), size: ColumnSize.S),
                  DataColumn2(label: const Text('Status'), fixedWidth: 100, onSort: sortableSorters[5]),
                  const DataColumn2(label: Text('Actions'), fixedWidth: 160),
                ],
                rows: rows.map((r) {
                  final tx = r['tx'] as TransactionsModel;
                  return DataRow2(
                    key: ValueKey(r['uuid']),
                    onTap: () {
                      TransactionsDialogsDetails.show(context, tx);
                    },
                    cells: [
                      DataCell(WidgetsWithTooltip(Text(r['date']), r['note'])),
                      DataCell(Text(r['balance'] ?? '')),
                      DataCell(Text(r['source'] ?? '')),
                      DataCell(Text(r['result'] ?? '')),
                      DataCell(Text(r['rate'] ?? '')),
                      DataCell(Text(r['status'] ?? '')),
                      DataCell(
                        TransactionsWidgetsButtons(
                          tx: tx,
                          cryptosController: _cryptosController,
                          txController: txController,
                          isTradable: txFlagPick(tx, "tradable"),
                          isClosable: txFlagPick(tx, "closable"),
                          isDeletable: txFlagPick(tx, "deletable"),
                          isUpdatable: txFlagPick(tx, "updatable"),
                          isRefundable: txFlagPick(tx, "refundable"),
                          isFinalizable: txFlagPick(tx, "finalizable"),
                          hasLeaf: txFlagPick(tx, "hasLeaf"),
                          hasTradeableLeaf: txFlagPick(tx, "hasTradeableLeaf"),
                          onAction: () {
                            widget.onStatusChanged();
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TransactionsModel> _processTx() {
    List<TransactionsModel> filtered;

    switch (_filterMode) {
      case 1:
        filtered = txs.where((t) => t.status == TransactionStatus.active.index).toList();
        break;

      case 2:
        filtered = txs.where((t) => t.status == TransactionStatus.partial.index).toList();
        break;

      case 3:
        filtered = txs.where((t) => t.status == TransactionStatus.inactive.index).toList();
        break;

      case 4:
        filtered = txs.where((t) => t.status == TransactionStatus.closed.index).toList();
        break;

      case 5:
        filtered = txs.where((t) => t.status == TransactionStatus.finalized.index).toList();
        break;

      default:
        filtered = txs;
    }

    return filtered;
  }
}
