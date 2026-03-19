import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
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

class _TransactionsJournalViewState extends State<TransactionsJournalView> with MixinsSortableTable<TransactionsJournalView> {
  late final TransactionsController _txController;
  late final CryptosController _cryptosController;

  @override
  void initState() {
    super.initState();
    _txController = locator<TransactionsController>();
    _cryptosController = locator<CryptosController>();

    rows = _buildRows(widget.transactions);

    onSort((d) => d['_timestamp'] as int, sortColumnIndex, sortAscending);
  }

  @override
  void didUpdateWidget(covariant TransactionsJournalView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transactions != widget.transactions) {
      rows = _buildRows(widget.transactions);

      final col = sortColumnIndex;
      final asc = sortAscending;

      switch (col) {
        case 0:
          onSort((d) => d['_timestamp'] as int, col, asc);
          break;

        case 1:
          onSort((d) => (d['_balanceSymbol'] as String, d['_balanceValue'] as double), col, asc);
          break;

        case 2:
          onSort((d) => (d['_sourceSymbol'] as String, d['_sourceValue'] as double), col, asc);
          break;

        case 3:
          onSort((d) => (d['_resultSymbol'] as String, d['_resultValue'] as double), col, asc);
          break;

        case 5:
          onSort((d) => d['status'] as String, col, asc);
          break;
      }

      setState(() {});
    }
  }

  List<Map<String, dynamic>> _buildRows(List<TransactionsModel> txs) {
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
    final table = rows;

    return WidgetsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
              child: DataTable2(
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
                  DataColumn2(label: Text('Date '), fixedWidth: 100, onSort: (col, asc) => onSort((d) => d['_timestamp'] as int, col, asc)),
                  DataColumn2(
                    label: Text('Balance '),
                    size: ColumnSize.M,
                    onSort: (col, asc) => onSort((d) => (d['_balanceSymbol'] as String, d['_balanceValue'] as double), col, asc),
                  ),
                  DataColumn2(
                    label: Text('From '),
                    size: ColumnSize.M,
                    onSort: (col, asc) => onSort((d) => (d['_sourceSymbol'] as String, d['_sourceValue'] as double), col, asc),
                  ),
                  DataColumn2(
                    label: Text('To '),
                    size: ColumnSize.M,
                    onSort: (col, asc) => onSort((d) => (d['_resultSymbol'] as String, d['_resultValue'] as double), col, asc),
                  ),
                  const DataColumn2(label: Text('Rate'), size: ColumnSize.S),
                  DataColumn2(
                    label: const Text('Status '),
                    fixedWidth: 100,
                    onSort: (col, asc) => onSort((d) => d['status'] as String, col, asc),
                  ),
                  const DataColumn2(label: Text('Actions'), fixedWidth: 130),
                ],
                rows: table.map((r) {
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
                            setState(() {});
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
