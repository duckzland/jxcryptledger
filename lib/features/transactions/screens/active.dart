import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:jxcryptledger/core/utils.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/header.dart';
import '../../../widgets/panel.dart';
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
  late List<Map<String, dynamic>> _rows;

  late TextEditingController _customRateController;

  late String _sourceSymbol;
  late String _resultSymbol;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  double? _customRate;
  double? _marketRate;

  Timer? _debounce;
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

    _rows = _buildRows(widget.transactions);

    _sortColumnIndex = 0;
    _sortAscending = false;
    _onSort((d) => d['_timestamp'] as int, _sortColumnIndex!, _sortAscending);
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

  @override
  void didUpdateWidget(covariant TransactionsActive oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transactions != widget.transactions && mounted) {
      _sourceSymbol = _cryptosRepo.getSymbol(widget.srid) ?? 'Unknown Coin';
      _resultSymbol = _cryptosRepo.getSymbol(widget.rrid) ?? 'Unknown Coin';

      _rows = _buildRows(widget.transactions);

      if (_sortColumnIndex != null) {
        final col = _sortColumnIndex!;
        final asc = _sortAscending;
        final currentRate = _customRate ?? _marketRate ?? 0.0;

        switch (col) {
          case 0:
            _onSort((d) => d['_timestamp'] as int, col, asc);
            break;

          case 1:
            _onSort((d) => d['_sourceValue'] as double, col, asc);

            break;

          case 2:
            _onSort((d) => d['_balanceValue'] as double, col, asc);
            break;

          case 3:
            _onSort((d) => d['_exchangedRateValue'] as double, col, asc);

          case 4:
            if (currentRate == 0) {
              _onSort((d) => d['_status'] as String, col, asc);
            }
            break;

          case 5:
            if (currentRate != 0) {
              _onSort((d) => d['_currentValue'] as double, col, asc);
            }
            break;

          case 6:
            if (currentRate != 0) {
              _onSort((d) => d['_profitLossValue'] as double, col, asc);
            }
            break;
          case 7:
            if (currentRate != 0) {
              _onSort((d) => d['status'] as String, col, asc);
            }
            break;
        }
      }

      setState(() {});
    }
  }

  Future<void> _loadMarketRate() async {
    try {
      final rate = await _ratesService.getStoredRate(widget.srid, widget.rrid);
      if (rate == -9999) {
        _ratesService.addQueue(widget.srid, widget.rrid);
        return;
      }
      if (mounted) {
        setState(() {
          _marketRate = rate;
          _rows = _buildRows(widget.transactions);
        });
      }
    } catch (e) {
      // Do something to process the error message?
    }
  }

  List<Map<String, dynamic>> _buildRows(List<TransactionsModel> txs) {
    final currentRate = _customRate ?? _marketRate ?? 0.0;
    final rows = <Map<String, dynamic>>[];

    for (final tx in txs) {
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

      rows.add({
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

        '_timestamp': tx.timestampAsMs,
        '_balanceValue': tx.rrAmount,
        '_sourceValue': tx.srAmount,
        '_exchangedRateValue': tx.rateDouble,
        '_currentValue': currentValue,
        '_profitLossValue': profitLoss,
      });
    }

    return rows;
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

    return WidgetsPanel(
      child: Column(
        children: [
          _buildHeader(
            txs: txs,
            currentRate: currentRate,
            averageRate: averageRate,
            totalSourceBalance: totalSourceBalance,
            totalBalance: totalBalance,
            avgPL: avgPL,
            plPercentage: plPercentage,
          ),

          const SizedBox(height: 20),

          _buildTable(currentRate),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required List<TransactionsModel> txs,
    required double currentRate,
    required double averageRate,
    required double totalSourceBalance,
    required double totalBalance,
    required double avgPL,
    required double plPercentage,
  }) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              '$_sourceSymbol to $_resultSymbol Trades',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text('Coin ID: ${widget.srid} - ${widget.rrid}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildPanels(
            averageRate: averageRate,
            totalSourceBalance: totalSourceBalance,
            totalBalance: totalBalance,
            avgPL: avgPL,
            plPercentage: plPercentage,
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 150,
          child: TextField(
            controller: _customRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: "Custom Rates", hintText: averageRate.toStringAsFixed(8)),
            onChanged: (value) {
              if (_debounce?.isActive ?? false) _debounce!.cancel();

              _debounce = Timer(const Duration(milliseconds: 100), () {
                setState(() {
                  _customRate = double.tryParse(value);
                });
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTable(double currentRate) {
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
          DataColumn2(
            label: Text('Date '),
            fixedWidth: 100,
            onSort: (col, asc) => _onSort((d) => d['_timestamp'] as int, col, asc),
          ),
          DataColumn2(
            size: ColumnSize.S,
            label: WidgetsHeader(title: 'From ', subtitle: _sourceSymbol),
            onSort: (col, asc) => _onSort((d) => d['_sourceValue'] as double, col, asc),
          ),
          DataColumn2(
            size: ColumnSize.S,
            label: WidgetsHeader(title: 'To ', subtitle: _resultSymbol),
            onSort: (col, asc) => _onSort((d) => d['_balanceValue'] as double, col, asc),
          ),
          DataColumn2(
            size: ColumnSize.S,
            label: WidgetsHeader(title: 'Exchanged Rate ', subtitle: '$_resultSymbol / $_sourceSymbol'),
            onSort: (col, asc) => _onSort((d) => d['_exchangedRateValue'] as double, col, asc),
          ),

          if (currentRate != 0) ...[
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsHeader(title: 'Current Rate ', subtitle: '$_resultSymbol / $_sourceSymbol'),
            ),
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsHeader(title: 'Current Value ', subtitle: _sourceSymbol),
              onSort: (col, asc) => _onSort((d) => d['_currentValue'] as double, col, asc),
            ),
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsHeader(title: 'Profit/Loss ', subtitle: _sourceSymbol),
              onSort: (col, asc) => _onSort((d) => d['_profitLossValue'] as double, col, asc),
            ),
          ],

          DataColumn2(
            label: Text('Status '),
            fixedWidth: 100,
            onSort: (col, asc) => _onSort((d) => d['status'] as String, col, asc),
          ),
          DataColumn2(label: Text('Actions'), fixedWidth: 140),
        ],

        rows: _rows.map((r) {
          return DataRow(
            cells: [
              DataCell(Text(r['date'])),
              DataCell(Text(r['from'])),
              DataCell(Text(r['to'])),
              DataCell(Text(r['exchangedRate'])),

              if (currentRate != 0) ...[
                DataCell(
                  WidgetsBalanceText(
                    text: r['currentRate'] ?? "-",
                    value: r['profitLevel'],
                    comparator: 0,
                    hidePrefix: true,
                  ),
                ),
                DataCell(
                  WidgetsBalanceText(
                    text: r['currentValue'] ?? "-",
                    value: r['profitLevel'],
                    comparator: 0,
                    hidePrefix: true,
                  ),
                ),
                DataCell(WidgetsBalanceText(text: r['profitLoss'] ?? "-", value: r['profitLevel'], comparator: 0)),
              ],

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

  Widget _buildPanels({
    required double averageRate,
    required double totalSourceBalance,
    required double totalBalance,
    required double avgPL,
    required double plPercentage,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildPanelItem(
          title: 'Total Balance',
          subtitle:
              '${Utils.formatSmartDouble(totalSourceBalance)} $_sourceSymbol - ${Utils.formatSmartDouble(totalBalance)} $_resultSymbol',
          value: 0,
          comparator: 0,
        ),

        _buildPanelItem(title: 'Avg Rate', subtitle: Utils.formatSmartDouble(averageRate), value: 0, comparator: 0),

        if (plPercentage != 0 && plPercentage.isFinite) ...[
          _buildPanelItem(
            title: 'Profit/Loss',
            subtitle: "${Utils.formatSmartDouble(avgPL)} $_sourceSymbol",
            value: plPercentage,
            comparator: 0,
          ),
          _buildPanelItem(
            title: 'Profit/Loss %',
            subtitle: '${Utils.formatSmartDouble(plPercentage, maxDecimals: 2)}%',
            value: plPercentage,
            comparator: 0,
          ),
        ],
      ],
    );
  }

  Widget _buildPanelItem({
    required String title,
    required String subtitle,
    required double value,
    required double comparator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 1),
        WidgetsBalanceText(text: subtitle, value: value, comparator: comparator, fontSize: 13),
      ],
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
