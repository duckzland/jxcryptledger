import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:jxcryptledger/core/utils.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
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
  late final CryptosController _cryptosController;
  late List<Map<String, dynamic>> _rows;

  late String _resultSymbol;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  final _calc = TransactionCalculation();

  @override
  void initState() {
    super.initState();

    _cryptosController = locator<CryptosController>();
    _resultSymbol = _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin';

    _rows = _buildRows(widget.transactions);

    _sortColumnIndex = 0;
    _sortAscending = false;
    _onSort((d) => d['_timestamp'] as int, _sortColumnIndex!, _sortAscending);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsOverview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transactions != widget.transactions && mounted) {
      _resultSymbol = _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin';
      _rows = _buildRows(widget.transactions);

      if (_sortColumnIndex != null) {
        final col = _sortColumnIndex!;
        final asc = _sortAscending;

        switch (col) {
          case 0:
            _onSort((d) => d['_timestamp'] as int, col, asc);
            break;

          case 1:
            _onSort((d) => d['_balanceValue'] as double, col, asc);
            break;

          case 2:
            _onSort((d) => d['_sourceValue'] as double, col, asc);
            break;

          case 3:
            _onSort((d) => d['_exchangedRateValue'] as double, col, asc);

          case 4:
            _onSort((d) => d['status'] as String, col, asc);
            break;
        }
      }

      setState(() {});
    }
  }

  List<Map<String, dynamic>> _buildRows(List<TransactionsModel> txs) {
    final rows = <Map<String, dynamic>>[];

    for (final tx in txs) {
      final sourceCoinSymbol = _cryptosController.getSymbol(tx.srId);

      rows.add({
        'balance': '${tx.balanceText} $_resultSymbol',
        'source': '${tx.srAmountText} $sourceCoinSymbol',
        'exchangedRate': '${tx.rateText} $_resultSymbol/$sourceCoinSymbol',
        'status': tx.statusText,
        'date': tx.timestampAsDate,
        'tx': tx,

        '_timestamp': tx.timestampAsMs,
        '_balanceValue': tx.balance,
        '_sourceValue': tx.srAmount,
        '_exchangedRateValue': tx.rateDouble,
      });
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final cumulativeSourceValue = _calc.totalBalance(widget.transactions);

    return WidgetsPanel(child: Column(children: [_buildHeader(cumulativeSourceValue), const SizedBox(height: 20), _buildTable()]));
  }

  Widget _buildHeader(double cumulativeSourceValue) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text('Coin ID: ${widget.id}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Total Balance", style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 1),
                  WidgetsBalanceText(
                    text: "${Utils.formatSmartDouble(cumulativeSourceValue)} ${_cryptosController.getSymbol(widget.id) ?? 'Unknown Coin'}",
                    value: 0,
                    comparator: 0,
                    fontSize: 13,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildTable() {
    return
    // @TODO: Why this will only work on SizedBox, while the github docs specified to use Flexible or Expanded?
    SizedBox(
      width: double.infinity,
      height: (_rows.length * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12,
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
          DataColumn2(label: Text('Date '), fixedWidth: 100, onSort: (col, asc) => _onSort((d) => d['_timestamp'] as int, col, asc)),
          DataColumn2(
            label: Text('Balance '),
            size: ColumnSize.M,
            onSort: (col, asc) => _onSort((d) => d['_balanceValue'] as double, col, asc),
          ),
          DataColumn2(
            label: Text('From '),
            size: ColumnSize.M,
            onSort: (col, asc) => _onSort((d) => d['_sourceValue'] as double, col, asc),
          ),
          DataColumn2(
            label: Text('Exchanged Rate '),
            size: ColumnSize.S,
            onSort: (col, asc) => _onSort((d) => d['_exchangedRateValue'] as double, col, asc),
          ),
          DataColumn2(label: Text('Status '), fixedWidth: 100, onSort: (col, asc) => _onSort((d) => d['status'] as String, col, asc)),
          DataColumn2(label: Text('Actions'), fixedWidth: 140),
        ],

        rows: _rows.map((r) {
          return DataRow(
            cells: [
              DataCell(Text(r['date'])),
              DataCell(Text(r['balance'])),
              DataCell(Text(r['source'])),
              DataCell(Text(r['exchangedRate'])),
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
    );
  }

  void _onSort<T>(T Function(Map<String, dynamic> d) getField, int columnIndex, bool ascending) {
    setState(() {
      _rows.sort((a, b) {
        final aField = getField(a);
        final bField = getField(b);

        if (aField is (String, num) && bField is (String, num)) {
          final c1 = aField.$1.compareTo(bField.$1);
          if (c1 != 0) return ascending ? c1 : -c1;

          final c2 = aField.$2.compareTo(bField.$2);
          return ascending ? c2 : -c2;
        }

        return ascending
            ? Comparable.compare(aField as Comparable, bField as Comparable)
            : Comparable.compare(bField as Comparable, aField as Comparable);
      });

      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }
}
