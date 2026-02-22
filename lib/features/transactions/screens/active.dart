import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:jxcryptledger/core/utils.dart';

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

  List<Map<String, dynamic>> _tableRows = [];

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

    final sortedTxs = List<TransactionsModel>.from(widget.transactions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final newRows = <Map<String, dynamic>>[];

    for (final tx in sortedTxs) {
      final sourceSymbol = _cryptosRepo.getSymbol(tx.srId);
      final resultSymbol = _cryptosRepo.getSymbol(tx.rrId);

      double? currentValue;
      double? profitLoss;
      int profitLevel = 0;

      if (currentRate != 0) {
        currentValue = tx.balance / currentRate;
        profitLoss = currentValue - tx.balance;

        if (profitLoss > 0) {
          profitLevel = 1;
        } else if (profitLoss < 0) {
          profitLevel = -1;
        }
      }

      newRows.add({
        'from': '${tx.srAmountText} $sourceSymbol',
        'to': '${tx.balanceText} $resultSymbol',
        'exchangedRate': tx.rateText,
        'currentRate': currentRate == 0 ? null : Utils.formatSmartDouble(currentRate),
        'currentValue': currentRate == 0 ? null : '${Utils.formatSmartDouble(currentValue!)} $sourceSymbol',
        'profitLoss': currentRate == 0
            ? null
            : '${profitLoss! > 0 ? '+' : ''}${Utils.formatSmartDouble(profitLoss)} $sourceSymbol',
        'profitLevel': profitLevel,
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
    final txs = widget.transactions;
    final currentRate = _customRate ?? _marketRate ?? 0.0;

    final averageRate = _calc.averageExchangedRate(txs);
    final totalSourceBalance = _calc.totalSourceBalance(txs);
    final totalBalance = _calc.totalBalance(txs);
    final avgPL = _calc.averageProfitLoss(txs, currentRate);
    final plPercentage = _calc.profitLossPercentage(txs, currentRate);

    final color = plPercentage > 0
        ? AppTheme.success
        : plPercentage == 0
        ? AppTheme.error
        : AppTheme.text;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.separator),
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.panelBg,
      ),
      child: Column(
        children: [
          _buildHeader(averageRate: averageRate, totalSourceBalance: totalSourceBalance, totalBalance: totalBalance),

          const SizedBox(height: 20),

          _buildTable(currentRate),

          const SizedBox(height: 20),

          _buildFooter(
            averageRate: averageRate,
            totalSourceBalance: totalSourceBalance,
            totalBalance: totalBalance,
            avgPL: avgPL,
            plPercentage: plPercentage,
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({required double averageRate, required double totalSourceBalance, required double totalBalance}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin'} to ${_cryptosRepo.getSymbol(widget.rrid) ?? 'Unknown Coin'}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text('Coin ID: ${widget.srid} - ${widget.rrid}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
    );
  }

  Widget _buildTable(double currentRate) {
    return SizedBox(
      width: double.infinity,
      height: (_tableRows.length * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12,
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 12,
        headingRowHeight: AppTheme.tableHeadingRowHeight,
        dataRowHeight: AppTheme.tableDataRowMinHeight,
        minWidth: 900,
        showCheckboxColumn: false,

        columns: [
          DataColumn2(label: Text('From'), size: ColumnSize.S),
          DataColumn2(label: Text('To'), size: ColumnSize.S),
          DataColumn2(label: Text('Exchanged Rate'), size: ColumnSize.S),

          if (currentRate != 0) ...[
            DataColumn2(label: Text('Current Rate'), size: ColumnSize.S),
            DataColumn2(label: Text('Current Value'), size: ColumnSize.S),
            DataColumn2(label: Text('Profit/Loss'), size: ColumnSize.S),
          ],

          DataColumn2(label: Text('Status'), size: ColumnSize.S),
          DataColumn2(label: Text('Date'), size: ColumnSize.S),
          DataColumn2(label: Text('Actions'), size: ColumnSize.S),
        ],

        rows: _tableRows.map((r) {
          final color = r['profitLevel'] == 1
              ? AppTheme.success
              : r['profitLevel'] == -1
              ? AppTheme.error
              : AppTheme.text;

          return DataRow(
            cells: [
              DataCell(Text(r['from'])),
              DataCell(Text(r['to'])),
              DataCell(Text(r['exchangedRate'])),

              if (currentRate != 0) ...[
                DataCell(Text(r['currentRate'], style: TextStyle(color: color))),
                DataCell(Text(r['currentValue'], style: TextStyle(color: color))),
                DataCell(Text(r['profitLoss'], style: TextStyle(color: color))),
              ],

              DataCell(Text(r['status'])),
              DataCell(Text(r['date'])),
              DataCell(
                TransactionsButtons(
                  tx: r['tx'],
                  onAction: (mode, updatedTx) {
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

  Widget _buildFooter({
    required double averageRate,
    required double totalSourceBalance,
    required double totalBalance,
    required double avgPL,
    required double plPercentage,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildFooterItem(
          label: 'Total Balance',
          value:
              '${Utils.formatSmartDouble(totalSourceBalance)} ${_cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin'} - ${Utils.formatSmartDouble(totalBalance)} ${_cryptosRepo.getSymbol(widget.rrid) ?? 'Unknown Coin'}',
        ),

        _buildFooterItem(label: 'Avg Rate', value: Utils.formatSmartDouble(averageRate)),

        if (plPercentage != 0) ...[
          _buildFooterItem(
            label: 'P/L',
            value:
                "${plPercentage > 0 ? '+' : ''}${Utils.formatSmartDouble(avgPL)} ${_cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin'}",
            color: color,
          ),
          _buildFooterItem(
            label: 'P/L %',
            value: '${plPercentage > 0 ? '+' : ''}${Utils.formatSmartDouble(plPercentage, maxDecimals: 2)}%',
            color: color,
          ),
        ],
      ],
    );
  }

  Widget _buildFooterItem({required String label, required String value, Color color = AppTheme.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
