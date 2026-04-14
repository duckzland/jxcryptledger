import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/utils.dart';
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
    return _txController.collectTradableLeaves(data);
  }

  @override
  void initState() {
    super.initState();

    _rateController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _rateController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
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
        _rateController.addQueue(tx.rrId, tradeSourceId);
        if (_cachedRates[tx.rrId] != null) {
          rate = _cachedRates[tx.rrId]!;
        }
      } else {
        _cachedRates[tx.rrId] = rate;
      }

      final amount = rate == -9999 ? 0.0 : tx.balance * rate;

      rows.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': '${tx.srAmountText} $sourceSymbol \u203A ${tx.balanceText} $resultSymbol',
        'rate': rate == -9999 ? "" : "1 $resultSymbol = ${Utils.formatSmartDouble(rate)} $tradeSourceSymbol",
        'amount': rate == -9999 ? "" : "${Utils.formatSmartDouble(amount)} $tradeSourceSymbol",
        'tx': tx,
      });
    }
    return rows;
  }

  String _getTotalAmount(List<TransactionsModel> txs) {
    double total = 0.0;
    String result = "";

    for (final tx in txs) {
      final rate = _rateController.getStoredRate(tx.rrId, tradeSourceId);
      final amount = rate == -9999 ? 0.0 : tx.rrAmount * rate;

      if (rate != -9999) {
        total += amount;
      }
    }

    if (total > 0) {
      result = '${Utils.formatSmartDouble(total)} $tradeSourceSymbol';
    }

    return result;
  }

  Widget _buildTransactionsPanel() {
    final table = _buildRows(tradableLeaves);
    final total = _getTotalAmount(tradableLeaves);

    return WidgetsPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 0,
        children: [
          SizedBox(
            width: double.infinity,
            height: ((table.length + 1) * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
              child: DataTable2(
                minWidth: 1200,
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
                  DataColumn2(label: Text('Amount '), size: ColumnSize.M),
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
                  DataRow(
                    color: WidgetStateProperty.all(AppTheme.headerBg),
                    cells: [
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(total, style: TextStyle(fontWeight: FontWeight.bold))),
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
