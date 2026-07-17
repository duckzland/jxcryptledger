
import 'package:data_table_2/data_table_2.dart';
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
            : '${tx.srAmountText} $sourceSymbol → ${tx.rrAmountText} $resultSymbol',
        'balance': '${tx.balanceText} $resultSymbol',
        'rate': rate == -9999 || tx.rrId == tradeSourceId ? "-" : "1 $resultSymbol = ${Utils.formatSmartDouble(rate)} $tradeSourceSymbol",
        'amount': rate == -9999 ? "" : "${Utils.formatSmartDouble(amount)} $tradeSourceSymbol",
        'uuid': tx.uuid,
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

      final amount = rate == -9999 ? 0.0 : tx.balance * rate;

      if (rate != -9999) {
        total = (total ?? 0.0) + amount;
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
          const DataColumn2(label: Text('Date '), fixedWidth: 100),
          const DataColumn2(label: Text('Transactions '), size: ColumnSize.M),
          const DataColumn2(label: Text('Balance '), size: ColumnSize.S),
          const DataColumn2(label: Text('Market Rate '), size: ColumnSize.S),
          const DataColumn2(label: Text('Return '), size: ColumnSize.S),
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

    final total = '${Utils.formatSmartDouble(ttl)} $tradeSourceSymbol';
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
          const DataColumn2(label: SizedBox.shrink(), fixedWidth: 100),
          const DataColumn2(label: SizedBox.shrink(), size: ColumnSize.M),
          const DataColumn2(label: SizedBox.shrink(), size: ColumnSize.S),
          const DataColumn2(label: SizedBox.shrink(), size: ColumnSize.S),
          const DataColumn2(label: SizedBox.shrink(), size: ColumnSize.S),
        ],
        rows: [
          DataRow(
            key: ValueKey('total-row'),
            color: WidgetStateProperty.all(AppTheme.tableHeaderBg),
            cells: [
              const DataCell(Text('Total Capital', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('', style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(
                Text("${Utils.formatSmartDouble(tradeCapital)} $tradeSourceSymbol", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const DataCell(Text('Total Return', style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(total, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          DataRow(
            key: ValueKey('profit-row'),
            color: WidgetStateProperty.all(AppTheme.tableHeaderBg),
            cells: [
              const DataCell(Text('Profit/Loss', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('', style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(WidgetsBalanceText(text: "${Utils.formatSmartDouble(pl)} $tradeSourceSymbol", value: pl, comparator: 0)),
              const DataCell(Text('', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataCell(Text('', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Text("Balance Snapshot", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18));
  }

  Widget _buildButtonPanel() {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [WidgetsButtonsAction(label: 'Close', onPressed: (_) => Navigator.pop(context))],
      ),
    );
  }
}
