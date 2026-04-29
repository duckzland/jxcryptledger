import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/button.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../../rates/controller.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsDialogsBalanceSnapshots extends StatefulWidget {
  final TransactionsModel? initialData;
  final TransactionsModel? parent;

  const TransactionsDialogsBalanceSnapshots({super.key, this.initialData, this.parent});

  @override
  State<TransactionsDialogsBalanceSnapshots> createState() => _TransactionsDialogsBalanceSnapshotsState();
}

class _TransactionsDialogsBalanceSnapshotsState extends State<TransactionsDialogsBalanceSnapshots> {
  CryptosController get _cryptoController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();
  RatesController get _rateController => locator<RatesController>();

  final Map<int, double> _cachedRates = {};

  double get tradeCapital {
    final data = widget.initialData;
    return data?.srAmount ?? 0;
  }

  String get tradeSourceSymbol {
    final data = widget.initialData;
    if (data == null) return "";

    return _cryptoController.getSymbol(data.srId) ?? "";
  }

  int get tradeSourceId {
    final data = widget.initialData;
    return data?.srId ?? 0;
  }

  List<TransactionsModel> get tradableLeaves {
    final data = widget.initialData;
    if (data == null) return [];

    final leaves = _txController.collectTradableLeaves(data);
    if (data.isPartial) {
      leaves.insert(0, data);
    }

    return leaves;
  }

  @override
  void initState() {
    super.initState();

    _rateController.addListener(_onControllerChanged);
    _populateRates();
  }

  @override
  void dispose() {
    _rateController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _populateRates() {
    for (final tx in tradableLeaves) {
      double rate = _rateController.getStoredRate(tx.rrId, tradeSourceId);

      if (rate == -9999) {
        _rateController.addQueue(tx.rrId, tradeSourceId);
      } else {
        _cachedRates[tx.rrId] = rate;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [_buildTitle(), _buildTransactionsPanel(), _buildButtonPanel()],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildRows(List<TransactionsModel> txs) {
    final rows = <Map<String, dynamic>>[];

    for (final tx in txs) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';
      double rate = _rateController.getStoredRate(tx.rrId, tradeSourceId);

      if (rate == -9999) {
        if (_cachedRates[tx.rrId] != null) {
          rate = _cachedRates[tx.rrId]!;
        }
      } else {
        _cachedRates[tx.rrId] = rate;
      }

      final amount = rate == -9999 ? 0.0 : tx.balance * rate;

      rows.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': tx.rrId == tradeSourceId
            ? 'Balance ${tx.balanceText} $resultSymbol'
            : '${tx.srAmountText} $sourceSymbol → ${tx.balanceText} $resultSymbol',
        'rate': rate == -9999 || tx.rrId == tradeSourceId ? "-" : "1 $resultSymbol = ${Utils.formatSmartDouble(rate)} $tradeSourceSymbol",
        'amount': rate == -9999 ? "" : "${Utils.formatSmartDouble(amount)} $tradeSourceSymbol",
        'tx': tx,
      });
    }

    return rows;
  }

  double? _getTotalAmount(List<TransactionsModel> txs) {
    double? total;

    for (final tx in txs) {
      double rate = _rateController.getStoredRate(tx.rrId, tradeSourceId);

      if (rate == -9999 && _cachedRates[tx.rrId] != null) {
        rate = _cachedRates[tx.rrId]!;
      }

      final amount = rate == -9999 ? 0.0 : tx.rrAmount * rate;

      if (rate != -9999) {
        total = (total ?? 0.0) + amount;
      }
    }

    return total;
  }

  Widget _buildTransactionsPanel() {
    final table = _buildRows(tradableLeaves);
    final ttl = _getTotalAmount(tradableLeaves);

    int ttlRows = table.length;
    String total = "";
    double pl = 0.0;

    if (ttl != null) {
      total = '${Utils.formatSmartDouble(ttl)} $tradeSourceSymbol';
      pl = Math.subtract(ttl, tradeCapital);
      ttlRows += 2;
    }

    return WidgetsPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 0,
        children: [
          SizedBox(
            width: double.infinity,
            height: ((ttlRows) * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
              child: DataTable2(
                minWidth: 800,
                columnSpacing: 12,
                horizontalMargin: 12,
                headingRowHeight: AppTheme.tableHeadingRowHeight,
                dataRowHeight: AppTheme.tableDataRowMinHeight,
                showCheckboxColumn: false,
                isHorizontalScrollBarVisible: false,
                columns: [
                  DataColumn2(label: Text('Date '), fixedWidth: 100),
                  DataColumn2(label: Text('Transactions '), size: ColumnSize.M),
                  DataColumn2(label: Text('Market Rate '), size: ColumnSize.S),
                  DataColumn2(label: Text('Return '), size: ColumnSize.S),
                ],
                rows: [
                  ...table.map((r) {
                    return DataRow(
                      cells: [
                        DataCell(Text(r['date'] ?? '')),
                        DataCell(Text(r['transaction'] ?? '')),
                        DataCell(Text(r['rate'] ?? '')),
                        DataCell(Text(r['amount'] ?? '')),
                      ],
                    );
                  }),
                  if (ttl != null)
                    DataRow(
                      color: WidgetStateProperty.all(AppTheme.headerBg),
                      cells: [
                        DataCell(Text('Total Capital', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(
                          Text(
                            "${Utils.formatSmartDouble(tradeCapital)} $tradeSourceSymbol",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(Text('Total Return', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(total, style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  if (ttl != null)
                    DataRow(
                      color: WidgetStateProperty.all(AppTheme.headerBg),
                      cells: [
                        DataCell(Text('Profit/Loss', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(WidgetsBalanceText(text: "${Utils.formatSmartDouble(pl)} $tradeSourceSymbol", value: pl, comparator: 0)),
                        DataCell(Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text("Balance Snapshot", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildButtonPanel() {
    return WidgetsPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [WidgetsButton(label: 'Close', onPressed: (_) => Navigator.pop(context))],
      ),
    );
  }
}
