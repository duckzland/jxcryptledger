import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/repository.dart';
import '../buttons.dart';
import '../model.dart';

class TransactionsJournalView extends StatefulWidget {
  final List<TransactionsModel> transactions;
  final VoidCallback onStatusChanged;

  const TransactionsJournalView({super.key, required this.transactions, required this.onStatusChanged});

  @override
  State<TransactionsJournalView> createState() => _TransactionsJournalViewState();
}

class _TransactionsJournalViewState extends State<TransactionsJournalView> {
  late final CryptosRepository _cryptosRepo;
  late List<Map<String, dynamic>> _rows;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _cryptosRepo = locator<CryptosRepository>();
    _rows = _buildRows(widget.transactions);
  }

  @override
  void didUpdateWidget(covariant TransactionsJournalView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transactions != widget.transactions) {
      _rows = _buildRows(widget.transactions);

      if (_sortColumnIndex != null) {
        final col = _sortColumnIndex!;
        final asc = _sortAscending;

        switch (col) {
          case 0:
            _rows.sort((a, b) => asc ? a['date'].compareTo(b['date']) : b['date'].compareTo(a['date']));
            break;
          case 1:
            _rows.sort((a, b) => asc ? a['balance'].compareTo(b['balance']) : b['balance'].compareTo(a['balance']));
            break;
          case 2:
            _rows.sort((a, b) => asc ? a['source'].compareTo(b['source']) : b['source'].compareTo(a['source']));
            break;
        }
      }

      setState(() {});
    }
  }

  List<Map<String, dynamic>> _buildRows(List<TransactionsModel> txs) {
    final rows = <Map<String, dynamic>>[];
    for (final tx in txs) {
      final sourceCoinSymbol = _cryptosRepo.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptosRepo.getSymbol(tx.rrId) ?? 'Unknown Coin';

      rows.add({
        'date': tx.timestampAsDate,
        'balance': '${tx.balanceText} $resultSymbol',
        'source': '${tx.srAmountText} $sourceCoinSymbol',
        'rate': '${tx.rateText} $resultSymbol/$sourceCoinSymbol',
        'status': tx.statusText,
        'tx': tx,
        '_timestamp': tx.timestamp,
        '_balanceValue': tx.rrAmount,
        '_balanceSymbol': resultSymbol,
        '_sourceValue': tx.srAmount,
        '_sourceSymbol': sourceCoinSymbol,
      });
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final table = _rows;

    return WidgetsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DataTable2(
              columnSpacing: 12,
              horizontalMargin: 12,
              headingRowHeight: AppTheme.tableHeadingRowHeight,
              dataRowHeight: AppTheme.tableDataRowMinHeight,
              showCheckboxColumn: false,
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              isHorizontalScrollBarVisible: false,
              columns: [
                DataColumn2(
                  label: Text('Date'),
                  fixedWidth: 100,
                  onSort: (i, asc) => _onSort((d) => d['_timestamp'], i, asc),
                ),
                DataColumn2(
                  label: Text('Balance'),
                  size: ColumnSize.M,
                  onSort: (i, asc) => _onSort(
                    (d) {
                      return (d['_balanceSymbol'], d['_balanceValue']);
                    },
                    i,
                    asc,
                  ),
                ),
                DataColumn2(
                  label: Text('From'),
                  size: ColumnSize.M,
                  onSort: (i, asc) => _onSort(
                    (d) {
                      return (d['_sourceSymbol'], d['_sourceValue']);
                    },
                    i,
                    asc,
                  ),
                ),
                const DataColumn2(label: Text('Rate'), size: ColumnSize.S),
                DataColumn2(
                  label: const Text('Status'),
                  fixedWidth: 100,
                  onSort: (i, asc) => _onSort((d) => d['status'] as String, i, asc),
                ),
                const DataColumn2(label: Text('Actions'), fixedWidth: 140),
              ],
              rows: table.map((r) {
                return DataRow(
                  cells: [
                    DataCell(Text(r['date'] ?? '')),
                    DataCell(Text(r['balance'] ?? '')),
                    DataCell(Text(r['source'] ?? '')),
                    DataCell(Text(r['rate'] ?? '')),
                    DataCell(Text(r['status'] ?? '')),
                    DataCell(
                      TransactionsButtons(
                        tx: r['tx'],
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
        ],
      ),
    );
  }

  void _onSort<T>(T Function(Map<String, dynamic> d) getField, int columnIndex, bool ascending) {
    setState(() {
      _rows.sort((a, b) {
        final aField = getField(a);
        final bField = getField(b);

        // Tuple sorting: (symbol, value)
        if (aField is (String, num) && bField is (String, num)) {
          final symbolCompare = aField.$1.compareTo(bField.$1);
          if (symbolCompare != 0) {
            return ascending ? symbolCompare : -symbolCompare;
          }

          final valueCompare = aField.$2.compareTo(bField.$2);
          return ascending ? valueCompare : -valueCompare;
        }

        // Fallback for simple Comparable
        return ascending
            ? Comparable.compare(aField as Comparable, bField as Comparable)
            : Comparable.compare(bField as Comparable, aField as Comparable);
      });

      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  (String symbol, double value) _parseValueSymbol(String input) {
    final parts = input.split(' ');
    if (parts.length < 2) return ('', 0);

    final value = double.tryParse(parts[0]) ?? 0;
    final symbol = parts[1];

    return (symbol, value);
  }
}
