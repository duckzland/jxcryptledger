import 'package:flutter/material.dart';
import 'package:jxcryptledger/core/utils.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../cryptos/repository.dart';
import '../../rates/service.dart';
import '../buttons.dart';
import '../calculations.dart';
import '../model.dart';

class TransactionsActive extends StatefulWidget {
  final int srid;
  final int rrid;

  final List<TransactionsModel> transactions;
  final VoidCallback onStatusChanged;

  const TransactionsActive({
    super.key,
    required this.srid,
    required this.rrid,
    required this.transactions,
    required this.onStatusChanged,
  });

  @override
  State<TransactionsActive> createState() => _TransactionsActiveState();
}

class _TransactionsActiveState extends State<TransactionsActive> {
  late final CryptosRepository _cryptosRepo;
  late final RatesService _ratesService;

  late TextEditingController _customRateController;

  double? _customRate;
  double? _marketRate;

  List<PlutoColumn> _columns = [];
  List<PlutoRow> _rows = [];

  final _calc = TransactionCalculation();

  @override
  void initState() {
    super.initState();
    _cryptosRepo = locator<CryptosRepository>();
    _ratesService = locator<RatesService>();
    _customRateController = TextEditingController();
    _loadMarketRate();

    _ratesService.addListener(_onRatesUpdated);
  }

  @override
  void dispose() {
    _customRateController.dispose();
    _ratesService.removeListener(_onRatesUpdated);
    super.dispose();
  }

  void _onRatesUpdated() {
    _loadMarketRate();
  }

  Future<void> _loadMarketRate() async {
    final rate = await _ratesService.getRate(widget.srid, widget.rrid);

    setState(() {
      _marketRate = rate;
    });

    _buildTableData();
  }

  void _buildTableData() {
    final currentRate = _customRate ?? _marketRate ?? 0.0;

    _columns.clear();
    _rows.clear();

    final newColumns = <PlutoColumn>[];
    final newRows = <PlutoRow>[];

    // Sort transactions by timestamp descending
    final sortedTxs = List<TransactionsModel>.from(widget.transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Build columns
    newColumns.addAll([
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
        title: 'To',
        field: 'balance',
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
    ]);

    // Only add these if currentRate != 0
    if (currentRate != 0) {
      newColumns.addAll([
        PlutoColumn(
          title: 'Current Rate',
          field: 'currentRate',
          type: PlutoColumnType.text(),
          width: 120,
          enableContextMenu: false,
          enableDropToResize: false,
        ),
        PlutoColumn(
          title: 'Current Value',
          field: 'currentValue',
          type: PlutoColumnType.text(),
          width: 120,
          enableContextMenu: false,
          enableDropToResize: false,
        ),
        PlutoColumn(
          title: 'Profit/Loss',
          field: 'profitLoss',
          type: PlutoColumnType.text(),
          width: 120,
          enableContextMenu: false,
          enableDropToResize: false,
        ),
      ]);
    }

    // Always add these
    newColumns.addAll([
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
        width: 120,
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

    // Build rows
    for (final tx in sortedTxs) {
      // This must be inverted, because we are displaying SRID
      final currentValue = tx.balance / currentRate;
      final profitLoss = currentValue - tx.balance;

      final statusText = tx.statusText;
      final dateText = tx.timestampAsDate;
      final resultCoinSymbol = _cryptosRepo.getSymbol(tx.rrId);
      final sourceCoinSymbol = _cryptosRepo.getSymbol(tx.srId);

      final cells = {
        'source': PlutoCell(value: '${tx.srAmountText} $sourceCoinSymbol'),
        'balance': PlutoCell(value: '${tx.balanceText} $resultCoinSymbol'),
        'exchangedRate': PlutoCell(value: tx.rate),
      };

      // Only include these if currentRate != 0
      if (currentRate != 0) {
        cells.addAll({
          'currentRate': PlutoCell(value: Utils.formatSmartDouble(currentRate)),
          'currentValue': PlutoCell(value: '${Utils.formatSmartDouble(currentValue)} $sourceCoinSymbol'),
          'profitLoss': PlutoCell(value: '${Utils.formatSmartDouble(profitLoss)} $sourceCoinSymbol'),
        });
      }

      cells.addAll({
        'status': PlutoCell(value: statusText),
        'date': PlutoCell(value: dateText),
        'actions': PlutoCell(value: tx),
      });

      newRows.add(PlutoRow(cells: cells));
    }

    if (mounted) {
      setState(() {
        _columns = newColumns;
        _rows = newRows;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final txs = widget.transactions;
    final currentRate = _customRate ?? _marketRate ?? 0.0;

    final averageRate = _calc.averageExchangedRate(txs);
    final totalSourceBalance = _calc.totalSourceBalance(txs);
    final totalBalance = _calc.totalBalance(txs);
    final avgPL = _calc.averageProfitLoss(txs, currentRate);
    final plPercentage = _calc.profitLossPercentage(txs, currentRate);

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
                      '${_cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin'} to ${_cryptosRepo.getSymbol(widget.rrid) ?? 'Unknown Coin'}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Coin ID: ${widget.srid} - ${widget.rrid}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Total Balance: ${Utils.formatSmartDouble(totalSourceBalance)} ${_cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin'} - ${Utils.formatSmartDouble(totalBalance)} ${_cryptosRepo.getSymbol(widget.rrid) ?? 'Unknown Coin'}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: 150,
                child: TextField(
                  controller: _customRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: "Custom Rates", hintText: averageRate.toStringAsFixed(8)),
                  onChanged: (value) {
                    setState(() {
                      _customRate = double.tryParse(value);
                      _buildTableData();
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Table
          SizedBox(
            height: (_rows.length * 46.0) + 62,
            child: PlutoGrid(
              key: ValueKey('${_columns.length}-${_rows.length}-${_customRate ?? 0}'),
              columns: _columns,
              rows: _rows,
              noRowsWidget: const Center(child: Text('No transactions')),
              configuration: AppPlutoTheme.config,
              mode: PlutoGridMode.select,
              onRowSecondaryTap: (event) {},
              onLoaded: (PlutoGridOnLoadedEvent event) {
                event.stateManager.setSelectingMode(PlutoGridSelectingMode.none);
                event.stateManager.activateColumnsAutoSize();
              },
            ),
          ),

          const SizedBox(height: 20),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFooterItem(
                label: 'Total Balance',
                value:
                    '${Utils.formatSmartDouble(totalSourceBalance)} ${_cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin'} - ${Utils.formatSmartDouble(totalBalance)} ${_cryptosRepo.getSymbol(widget.rrid) ?? 'Unknown Coin'}',
              ),
              _buildFooterItem(label: 'Avg Rate', value: Utils.formatSmartDouble(averageRate)),

              if (currentRate != 0) ...[
                _buildFooterItem(
                  label: 'P/L',
                  value:
                      "${plPercentage > 0 ? '+' : ''}${Utils.formatSmartDouble(avgPL)} ${_cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin'}",
                ),
                _buildFooterItem(
                  label: 'P/L %',
                  value: '${plPercentage > 0 ? '+' : ''}${Utils.formatSmartDouble(plPercentage, maxDecimals: 2)}%',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
