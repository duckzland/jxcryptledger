import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:jxcryptledger/core/utils.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../cryptos/repository.dart';
import '../buttons.dart';
import '../calculations.dart';
import '../model.dart';

class TransactionsOverview extends StatefulWidget {
  final int id;
  final List<TransactionsModel> transactions;
  final VoidCallback onStatusChanged;

  const TransactionsOverview({super.key, required this.id, required this.transactions, required this.onStatusChanged});

  @override
  State<TransactionsOverview> createState() => _TransactionsOverviewState();
}

class _TransactionsOverviewState extends State<TransactionsOverview> {
  late final CryptosRepository _cryptosRepo;

  List<Map<String, dynamic>> _tableRows = [];

  final _calc = TransactionCalculation();

  @override
  void initState() {
    super.initState();

    _cryptosRepo = locator<CryptosRepository>();
    _buildTableData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _buildTableData() {
    final sortedTxs = List<TransactionsModel>.from(widget.transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final newRows = <Map<String, dynamic>>[];

    for (final tx in sortedTxs) {
      final resultCoinSymbol = _cryptosRepo.getSymbol(tx.rrId);
      final sourceCoinSymbol = _cryptosRepo.getSymbol(tx.srId);

      newRows.add({
        'balance': '${tx.balanceText} $resultCoinSymbol',
        'source': '${tx.srAmountText} $sourceCoinSymbol',
        'exchangedRate': '${tx.rateText} $resultCoinSymbol/$sourceCoinSymbol',
        'status': tx.statusText,
        'date': tx.timestampAsDate,
        'tx': tx,
      });
    }

    if (mounted) {
      setState(() {
        _tableRows = newRows;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cumulativeSourceValue = _calc.totalBalance(widget.transactions);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.separator),
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.panelBg,
      ),
      child: Column(children: [_buildHeader(cumulativeSourceValue), const SizedBox(height: 20), _buildTable()]),
    );
  }

  Widget _buildHeader(double cumulativeSourceValue) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _cryptosRepo.getSymbol(widget.id) ?? 'Unknown Coin',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text('Coin ID: ${widget.id}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 8),
              Text(
                "Total Balance: ${Utils.formatSmartDouble(cumulativeSourceValue)}"
                "${_cryptosRepo.getSymbol(widget.id) ?? 'Unknown Coin'}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return SizedBox(
      width: double.infinity,
      height: (_tableRows.length * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12,
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        headingRowHeight: AppTheme.tableHeadingRowHeight,
        dataRowHeight: AppTheme.tableDataRowMinHeight,
        minWidth: 700,
        showCheckboxColumn: false,

        columns: const [
          DataColumn2(label: Text('Balance'), size: ColumnSize.S),
          DataColumn2(label: Text('From'), size: ColumnSize.S),
          DataColumn2(label: Text('Exchanged Rate'), size: ColumnSize.S),
          DataColumn2(label: Text('Status'), size: ColumnSize.S),
          DataColumn2(label: Text('Date'), size: ColumnSize.S),
          DataColumn2(label: Text('Actions'), size: ColumnSize.S),
        ],

        rows: _tableRows.map((r) {
          return DataRow(
            cells: [
              DataCell(Text(r['balance'])),
              DataCell(Text(r['source'])),
              DataCell(Text(r['exchangedRate'])),
              DataCell(Text(r['status'])),
              DataCell(Text(r['date'])),
              DataCell(
                TransactionsButtons(
                  tx: r['tx'],
                  onAction: (mode, updatedTx, parentTx) {
                    widget.onStatusChanged();
                    _buildTableData();
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
