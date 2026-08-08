import 'package:data_table_2/data_table_2.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/buttons/action.dart';
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

class _TransactionsDialogsBalanceSnapshotsState extends State<TransactionsDialogsBalanceSnapshots> with MixinsState, MixinsTable {
  CryptosController get _cryptoController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();
  RatesController get _rateController => locator<RatesController>();

  final Map<int, Decimal> _cachedRates = {};

  Decimal get tradeCapital {
    final data = widget.initialData;
    return data?.srAmount ?? Decimal.zero;
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
  double get tableHeightOffset {
    final ttl = _getTotalAmount(tradableLeaves);
    return ttl == null ? 130 : 130 + (2 * tableRowHeight);
  }

  @override
  double get tableHeadingHeightOffset => 0;

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
      Decimal rate = _rateController.getStoredRate(tx.rrId, tradeSourceId);

      if (rate == Decimal.fromInt(-9999)) {
        _rateController.addQueue(tx.rrId, tradeSourceId);
      } else {
        _cachedRates[tx.rrId] = rate;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(24),
      constraints: BoxConstraints(maxWidth: 1200),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [_buildTitle(), _buildTransactionsPanel(), _buildButtonPanel()],
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
      Decimal rate = _rateController.getStoredRate(tx.rrId, tradeSourceId);

      if (rate == Decimal.fromInt(-9999)) {
        if (_cachedRates[tx.rrId] != null) {
          rate = _cachedRates[tx.rrId]!;
        }
      } else {
        _cachedRates[tx.rrId] = rate;
      }

      final amount = rate == Decimal.fromInt(-9999) ? Decimal.zero : tx.balance * rate;

      rows.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': tx.rrId == tradeSourceId
            ? 'Balance ${tx.balanceText} $resultSymbol'
            : '${tx.srAmountText} $sourceSymbol → ${tx.rrAmountText} $resultSymbol',
        'balance': '${tx.balanceText} $resultSymbol',
        'rate': rate == Decimal.fromInt(-9999) || tx.rrId == tradeSourceId
            ? "-"
            : "1 $resultSymbol = ${Utils.formatSmartDecimal(rate)} $tradeSourceSymbol",
        'amount': rate == Decimal.fromInt(-9999) ? "" : "${Utils.formatSmartDecimal(amount)} $tradeSourceSymbol",
        'uuid': tx.uuid,
        'tx': tx,
      });
    }

    return rows;
  }

  Decimal? _getTotalAmount(List<TransactionsModel> txs) {
    Decimal? total;

    for (final tx in txs) {
      Decimal rate = _rateController.getStoredRate(tx.rrId, tradeSourceId);

      if (rate == Decimal.fromInt(-9999) && _cachedRates[tx.rrId] != null) {
        rate = _cachedRates[tx.rrId]!;
      }

      final amount = rate == Decimal.fromInt(-9999) ? Decimal.zero : tx.balance * rate;

      if (rate != Decimal.fromInt(-9999)) {
        total = (total ?? Decimal.zero) + amount;
      }
    }

    return total;
  }

  Widget _buildTransactionsPanel() {
    rows = _buildRows(tradableLeaves);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [_buildTable(), _buildTotal()]);
  }

  Widget _buildTable() {
    return SizedBox(
      width: double.infinity,
      height: tableCalculateAdjustedMaxHeight(),
      child: DataTable2(
        minWidth: 800,
        columnSpacing: 12,
        horizontalMargin: 12,
        headingRowHeight: tableHeadingHeight,
        dataRowHeight: tableRowHeight,
        showCheckboxColumn: false,
        isHorizontalScrollBarVisible: false,
        columns: [
          DataColumn2(label: Text('Date '), fixedWidth: 100),
          DataColumn2(label: Text('Transactions '), size: ColumnSize.M),
          DataColumn2(label: Text('Balance '), size: ColumnSize.S),
          DataColumn2(label: Text('Market Rate '), size: ColumnSize.S),
          DataColumn2(label: Text('Return '), size: ColumnSize.S),
        ],
        rows: [
          ...rows.map((r) {
            return DataRow(
              key: ValueKey(r['uuid']),
              cells: [
                DataCell(Text(r['date'] ?? '')),
                DataCell(Text(r['transaction'] ?? '')),
                DataCell(Text(r['balance'] ?? '')),
                DataCell(Text(r['rate'] ?? '')),
                DataCell(Text(r['amount'] ?? '')),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotal() {
    final ttl = _getTotalAmount(tradableLeaves);

    if (ttl == null) {
      return SizedBox.shrink();
    }

    final total = '${Utils.formatSmartDecimal(ttl)} $tradeSourceSymbol';
    final pl = Math.subtract(ttl, tradeCapital);

    return SizedBox(
      width: double.infinity,
      height: tableRowHeight * 2,
      child: DataTable2(
        minWidth: 800,
        columnSpacing: 12,
        horizontalMargin: 12,
        headingRowHeight: 0,
        dataRowHeight: tableRowHeight,
        isHorizontalScrollBarVisible: false,
        columns: [
          DataColumn2(label: SizedBox.shrink(), fixedWidth: 100),
          DataColumn2(label: SizedBox.shrink(), size: ColumnSize.M),
          DataColumn2(label: SizedBox.shrink(), size: ColumnSize.S),
          DataColumn2(label: SizedBox.shrink(), size: ColumnSize.S),
          DataColumn2(label: SizedBox.shrink(), size: ColumnSize.S),
        ],
        rows: [
          DataRow(
            key: ValueKey('total-row'),
            color: WidgetStateProperty.all(AppTheme.tableHeaderBg),
            cells: [
              DataCell(Text('Total Capital', style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text('', style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text("${Utils.formatSmartDecimal(tradeCapital)} $tradeSourceSymbol", style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text('Total Return', style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(total, style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          DataRow(
            key: ValueKey('profit-row'),
            color: WidgetStateProperty.all(AppTheme.tableHeaderBg),
            cells: [
              DataCell(Text('Profit/Loss', style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text('', style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(WidgetsBalanceText(text: "${Utils.formatSmartDecimal(pl)} $tradeSourceSymbol", value: pl.toDouble(), comparator: 0)),
              DataCell(Text('', style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text('', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text("Balance Snapshot", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildButtonPanel() {
    return Padding(
      padding: EdgeInsets.only(top: 15.0, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [WidgetsButtonsAction(label: 'Close', onPressed: (_) => Navigator.pop(context))],
      ),
    );
  }
}
