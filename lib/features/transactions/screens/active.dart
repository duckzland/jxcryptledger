import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:jxcryptledger/core/utils.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/header.dart';
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

  late final String _sourceSymbol;
  late final String _resultSymbol;

  double? _customRate;
  double? _marketRate;

  Timer? _debounce;

  List<Map<String, dynamic>> _tableRows = [];

  final _calc = TransactionCalculation();

  @override
  void initState() {
    super.initState();
    _cryptosRepo = locator<CryptosRepository>();
    _sourceSymbol = _cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin';
    _resultSymbol = _cryptosRepo.getSymbol(widget.rrid) ?? 'Unknown Coin';

    _ratesService = locator<RatesService>();
    _ratesService.addListener(_onRatesUpdated);
    _loadMarketRate();

    _customRateController = TextEditingController();
  }

  @override
  void dispose() {
    _customRateController.dispose();
    _ratesService.removeListener(_onRatesUpdated);
    _debounce?.cancel();

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
      double currentValue = 0;
      double profitLoss = 0;
      double profitLevel = 0;

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
        'from': tx.srAmountText,
        'to': tx.balanceText,
        'exchangedRate': tx.rateText,
        'currentRate': currentRate == 0 ? null : Utils.formatSmartDouble(currentRate),
        'currentValue': currentRate == 0 ? null : Utils.formatSmartDouble(currentValue),
        'profitLoss': currentRate == 0 ? null : Utils.formatSmartDouble(profitLoss),
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
                '$_sourceSymbol to $_resultSymbol Trades',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text('Coin ID: ${widget.srid} - ${widget.rrid}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 8),
              Text(
                "Total Balance: ${Utils.formatSmartDouble(totalSourceBalance)} $_sourceSymbol - ${Utils.formatSmartDouble(totalBalance)} $_resultSymbol",
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
              if (_debounce?.isActive ?? false) _debounce!.cancel();

              _debounce = Timer(const Duration(milliseconds: 64), () {
                setState(() {
                  _customRate = double.tryParse(value);
                  _buildTableData();
                });
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
          DataColumn2(label: Text('Date'), size: ColumnSize.S),
          DataColumn2(
            size: ColumnSize.S,
            label: WidgetsTitle(title: 'From', subtitle: _sourceSymbol),
          ),
          DataColumn2(
            size: ColumnSize.S,
            label: WidgetsTitle(title: 'To', subtitle: _resultSymbol),
          ),
          DataColumn2(
            size: ColumnSize.S,
            label: WidgetsTitle(title: 'Exchanged Rate', subtitle: '$_resultSymbol / $_sourceSymbol'),
          ),

          if (currentRate != 0) ...[
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsTitle(title: 'Current Rate', subtitle: '$_resultSymbol / $_sourceSymbol'),
            ),
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsTitle(title: 'Current Value', subtitle: _sourceSymbol),
            ),
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsTitle(title: 'Profit/Loss', subtitle: _sourceSymbol),
            ),
          ],

          DataColumn2(label: Text('Status'), size: ColumnSize.S),
          DataColumn2(label: Text('Actions'), size: ColumnSize.S),
        ],

        rows: _tableRows.map((r) {
          return DataRow(
            cells: [
              DataCell(Text(r['date'])),
              DataCell(Text(r['from'])),
              DataCell(Text(r['to'])),
              DataCell(Text(r['exchangedRate'])),

              if (currentRate != 0) ...[
                DataCell(
                  WidgetsBalanceText(text: r['currentRate'], value: r['profitLevel'], comparator: 0, hidePrefix: true),
                ),
                DataCell(
                  WidgetsBalanceText(text: r['currentValue'], value: r['profitLevel'], comparator: 0, hidePrefix: true),
                ),
                DataCell(WidgetsBalanceText(text: r['profitLoss'], value: r['profitLevel'], comparator: 0)),
              ],

              DataCell(Text(r['status'])),
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
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildFooterItem(
          title: 'Total Balance',
          subtitle:
              '${Utils.formatSmartDouble(totalSourceBalance)} $_sourceSymbol - ${Utils.formatSmartDouble(totalBalance)} $_resultSymbol',
          value: 0,
          comparator: 0,
        ),

        _buildFooterItem(title: 'Avg Rate', subtitle: Utils.formatSmartDouble(averageRate), value: 0, comparator: 0),

        if (plPercentage != 0) ...[
          _buildFooterItem(
            title: 'Profit/Loss',
            subtitle: "${Utils.formatSmartDouble(avgPL)} $_sourceSymbol",
            value: plPercentage,
            comparator: 0,
          ),
          _buildFooterItem(
            title: 'Profit/Loss %',
            subtitle: '${Utils.formatSmartDouble(plPercentage, maxDecimals: 2)}%',
            value: plPercentage,
            comparator: 0,
          ),
        ],
      ],
    );
  }

  Widget _buildFooterItem({
    required String title,
    required String subtitle,
    required double value,
    required double comparator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        WidgetsBalanceText(text: subtitle, value: value, comparator: comparator, fontSize: 14),
      ],
    );
  }
}
