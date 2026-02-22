import 'package:flutter/material.dart';
import 'package:jxcryptledger/core/utils.dart';
import 'package:pluto_grid/pluto_grid.dart';

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

  final List<PlutoColumn> _columns = [];
  final List<PlutoRow> _rows = [];

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
    _columns.clear();
    _rows.clear();

    // Sort transactions by timestamp descending
    final sortedTxs = List<TransactionsModel>.from(widget.transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Build columns
    _columns.addAll([
      PlutoColumn(
        title: 'Balance',
        field: 'balance',
        type: PlutoColumnType.text(),
        width: 100,
        enableContextMenu: false,
        enableDropToResize: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'From',
        field: 'source',
        type: PlutoColumnType.text(),
        width: 120,
        enableContextMenu: false,
        enableDropToResize: false,
        enableSorting: false,
      ),
      PlutoColumn(
        title: 'Exchanged Rate',
        field: 'exchangedRate',
        type: PlutoColumnType.text(),
        width: 120,
        enableContextMenu: false,
        enableDropToResize: false,
      ),
      PlutoColumn(
        title: 'Status',
        field: 'status',
        type: PlutoColumnType.text(),
        width: 80,
        enableContextMenu: false,
        enableDropToResize: false,
      ),
      PlutoColumn(
        title: 'Date',
        field: 'date',
        type: PlutoColumnType.text(),
        width: 100,
        enableContextMenu: false,
        enableDropToResize: false,
      ),
      PlutoColumn(
        title: 'Actions',
        field: 'actions',
        type: PlutoColumnType.text(),
        width: 140,
        enableContextMenu: false,
        enableDropToResize: false,
        enableSorting: false,
        renderer: (ctx) {
          final tx = ctx.row.cells['actions']!.value as TransactionsModel;

          return TransactionsButtons(
            tx: tx,
            onAction: (mode, updatedTx) {
              widget.onStatusChanged();
              _buildTableData();
            },
          );
        },
      ),
    ]);

    for (final tx in sortedTxs) {
      final exchangedRate = tx.srAmount > 0 ? tx.srAmount / tx.rrAmount : 0.0;

      final statusText = tx.statusText;
      final dateText = tx.timestampAsDate;
      final resultCoinSymbol = _cryptosRepo.getSymbol(tx.rrId);
      final sourceCoinSymbol = _cryptosRepo.getSymbol(tx.srId);

      final cells = {
        'balance': PlutoCell(value: '${tx.balanceText} $resultCoinSymbol'),
        'source': PlutoCell(value: '${tx.srAmountText} $sourceCoinSymbol'),
        'exchangedRate': PlutoCell(value: Utils.formatSmartDouble(exchangedRate)),
        'status': PlutoCell(value: statusText),
        'date': PlutoCell(value: dateText),
        'actions': PlutoCell(value: tx),
      };

      _rows.add(PlutoRow(cells: cells));
    }

    if (mounted) {
      setState(() {});
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
      ),
      child: Column(
        children: [
          // Header
          Row(
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
                      "Total Balance: ${Utils.formatSmartDouble(cumulativeSourceValue)} ${_cryptosRepo.getSymbol(widget.id) ?? 'Unknown Coin'}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Table
          SizedBox(
            height: (_rows.length * 34.0) + 40,
            child: PlutoGrid(
              columns: _columns,
              rows: _rows,
              noRowsWidget: const Center(child: Text('No transactions')),
              configuration: AppPlutoTheme.config,
              mode: PlutoGridMode.readOnly,
              onRowSecondaryTap: (event) {},
            ),
          ),
        ],
      ),
    );
  }
}
