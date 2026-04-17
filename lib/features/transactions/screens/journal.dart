import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/scrollto.dart';
import '../../../mixins/scrollto_table.dart';
import '../../../mixins/sortable_table.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../widgets/buttons.dart';
import '../model.dart';

class TransactionsJournalView extends StatefulWidget {
  final List<TransactionsModel> transactions;
  final VoidCallback onStatusChanged;

  const TransactionsJournalView({super.key, required this.transactions, required this.onStatusChanged});

  @override
  State<TransactionsJournalView> createState() => _TransactionsJournalViewState();
}

class _TransactionsJournalViewState extends State<TransactionsJournalView>
    with
        AutomaticKeepAliveClientMixin,
        MixinsSortableTable<TransactionsJournalView>,
        MixinsScrollToTable<TransactionsJournalView, TransactionsModel> {
  late final TransactionsController _txController;
  late final CryptosController _cryptosController;

  late List<TransactionsModel> txs;

  @override
  final scrollUtil = ScrollTo();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _txController = locator<TransactionsController>();
    _cryptosController = locator<CryptosController>();

    txs = widget.transactions;

    sorters = {
      0: (col, asc) => onSort((d) => d['_timestamp'] as int, col, asc),
      1: (col, asc) => onSort((d) => (d['_balanceSymbol'] as String, d['_balanceValue'] as double), col, asc),
      2: (col, asc) => onSort((d) => (d['_sourceSymbol'] as String, d['_sourceValue'] as double), col, asc),
      3: (col, asc) => onSort((d) => (d['_resultSymbol'] as String, d['_resultValue'] as double), col, asc),
      5: (col, asc) => onSort((d) => d['status'] as String, col, asc),
    };

    rows = _buildRows();
    applySorting();
  }

  @override
  void dispose() {
    scrollUtil.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsJournalView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (_txController.isBothEqualGroup(oldWidget.transactions, widget.transactions)) {
      return;
    }

    setState(() {
      final ntx = _txController.findNew(txs);
      txs = widget.transactions;
      rows = _buildRows();
      applySorting();
      if (ntx != null) {
        scrollToTableNewRow(ntx);
      }
    });
  }

  List<Map<String, dynamic>> _buildRows() {
    final rows = <Map<String, dynamic>>[];

    for (final tx in txs) {
      final sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptosController.getSymbol(tx.rrId) ?? 'Unknown Coin';

      rows.add({
        'date': tx.timestampAsFormattedDate,
        'balance': '${tx.balanceText} $resultSymbol',
        'source': '${tx.srAmountText} $sourceSymbol',
        'result': '${tx.rrAmountText} $resultSymbol',
        'rate': '${tx.rateText} $resultSymbol/$sourceSymbol',
        'status': tx.statusText,
        'tx': tx,

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
    return rows;
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
                scrollController: scrollUtil.controller,
                minWidth: 1200,
                columnSpacing: 12,
                horizontalMargin: 12,
                headingRowHeight: AppTheme.tableHeadingRowHeight,
                dataRowHeight: AppTheme.tableDataRowMinHeight,
                showCheckboxColumn: false,
                sortColumnIndex: sortColumnIndex,
                sortAscending: sortAscending,
                isHorizontalScrollBarVisible: false,
                columns: [
                  DataColumn2(label: const Text('Date'), fixedWidth: 100, onSort: sorters[0]),
                  DataColumn2(label: const Text('Balance'), size: ColumnSize.M, onSort: sorters[1]),
                  DataColumn2(label: const Text('From'), size: ColumnSize.M, onSort: sorters[2]),
                  DataColumn2(label: const Text('To'), size: ColumnSize.M, onSort: sorters[3]),
                  const DataColumn2(label: Text('Rate'), size: ColumnSize.S),
                  DataColumn2(label: const Text('Status'), fixedWidth: 100, onSort: sorters[5]),
                  const DataColumn2(label: Text('Actions'), fixedWidth: 160),
                ],
                rows: rows.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(Text(r['date'] ?? '')),
                      DataCell(Text(r['balance'] ?? '')),
                      DataCell(Text(r['source'] ?? '')),
                      DataCell(Text(r['result'] ?? '')),
                      DataCell(Text(r['rate'] ?? '')),
                      DataCell(Text(r['status'] ?? '')),
                      DataCell(
                        TransactionsWidgetsButtons(
                          tx: r['tx'],
                          cryptosController: _cryptosController,
                          txController: _txController,
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
}
