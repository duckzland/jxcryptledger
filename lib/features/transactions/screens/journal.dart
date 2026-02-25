import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
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
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _cryptosRepo = locator<CryptosRepository>();
  }

  List<Map<String, dynamic>> get _tableRows {
    final rows = <Map<String, dynamic>>[];
    for (final tx in widget.transactions) {
      final sourceCoinSymbol = _cryptosRepo.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptosRepo.getSymbol(tx.rrId) ?? 'Unknown Coin';

      rows.add({
        'date': tx.timestampAsDate,
        'balance': '${tx.balanceText} $resultSymbol',
        'source': '${tx.srAmountText} $sourceCoinSymbol',
        'rate': '${tx.rateText} $resultSymbol/$sourceCoinSymbol',
        'status': tx.statusText,
        'tx': tx,
      });
    }
    return rows;
  }

  void _onSort<T>(Comparable<T> Function(Map<String, dynamic> d) getField, int columnIndex, bool ascending) {
    final rows = _tableRows;
    rows.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final table = _tableRows;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.separator),
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.panelBg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          Text('Trade Log', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: (table.length * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12,
            child: DataTable2(
              columnSpacing: 12,
              horizontalMargin: 12,
              headingRowHeight: AppTheme.tableHeadingRowHeight,
              dataRowHeight: AppTheme.tableDataRowMinHeight,
              minWidth: 700,
              showCheckboxColumn: false,
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              columns: [
                DataColumn2(
                  label: const Text('Date'),
                  size: ColumnSize.S,
                  onSort: (i, asc) => _onSort((d) => d['date'] as String, i, asc),
                ),
                DataColumn2(
                  label: const Text('Balance'),
                  size: ColumnSize.S,
                  numeric: true,
                  onSort: (i, asc) => _onSort((d) => d['balance'] as String, i, asc),
                ),
                DataColumn2(
                  label: const Text('From'),
                  size: ColumnSize.S,
                  onSort: (i, asc) => _onSort((d) => d['source'] as String, i, asc),
                ),
                const DataColumn2(label: Text('Rate'), size: ColumnSize.S),
                const DataColumn2(label: Text('Status'), size: ColumnSize.S),
                const DataColumn2(label: Text('Actions'), size: ColumnSize.S),
              ],
              rows: table.map((r) {
                return DataRow(
                  cells: [
                    DataCell(Text(r['date'])),
                    DataCell(Text(r['balance'])),
                    DataCell(Text(r['source'])),
                    DataCell(Text(r['rate'])),
                    DataCell(Text(r['status'])),
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
}
