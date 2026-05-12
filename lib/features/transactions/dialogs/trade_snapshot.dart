import 'dart:async';
import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/utils.dart';
import '../../../mixins/rates.dart';
import '../../../widgets/button.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../model.dart';

class TransactionsDialogsTradeSnapshots extends StatefulWidget {
  final int srId;
  final double totalAmount;
  final List<TransactionsModel>? transactions;

  const TransactionsDialogsTradeSnapshots({super.key, required this.srId, required this.totalAmount, this.transactions});

  @override
  State<TransactionsDialogsTradeSnapshots> createState() => _TransactionsDialogsTradeSnapshotsState();
}

class _TransactionsDialogsTradeSnapshotsState extends State<TransactionsDialogsTradeSnapshots>
    with MixinsRates<TransactionsDialogsTradeSnapshots> {
  CryptosController get _cryptoController => locator<CryptosController>();

  late String _selectedSymbol;
  late double _sourceAmount;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    ratesSource = widget.srId;

    _selectedSymbol = _cryptoController.getSymbol(widget.srId) ?? 'Unknown Coin';
    _sourceAmount = widget.totalAmount;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
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
              children: [
                Text(
                  "Trade Snapshot For ${Utils.formatSmartDouble(_sourceAmount)} $_selectedSymbol",
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                ),
                WidgetsPanel(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 0, children: [_buildCalculator()]),
                ),
                if (widget.transactions != null && widget.transactions!.isNotEmpty)
                  WidgetsPanel(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 0, children: [_buildTable()]),
                  ),
                WidgetsPanel(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [WidgetsButton(label: 'Close', onPressed: (_) => Navigator.pop(context))],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    final rows = <Map<String, dynamic>>[];

    for (final tx in widget.transactions!) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';

      rows.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': '${tx.srAmountText} $sourceSymbol → ${tx.balanceText} $resultSymbol',
        'tx': tx,
      });
    }

    return SizedBox(
      width: double.infinity,
      height: ((rows.length + 1) * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12,
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
          ],
          rows: [
            ...rows.map((r) {
              return DataRow(cells: [DataCell(Text(r['date'] ?? '')), DataCell(Text(r['transaction'] ?? ''))]);
            }),

            DataRow(
              color: WidgetStateProperty.all(AppTheme.headerBg),
              cells: [
                DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('${Utils.formatSmartDouble(_sourceAmount)} $_selectedSymbol', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculator() {
    return Form(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return SizedBox(
              width: double.infinity,
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCryptoInputColumn("To:", _buildResultCryptoField())),

                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 50), child: Icon(Icons.clear, size: 24)),

                  Expanded(child: _buildCryptoInputColumn("Rate:", _buildRatesAmountField())),

                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 50), child: Icon(Icons.arrow_forward, size: 24)),

                  Expanded(child: _buildCalculatedResult()),
                ],
              ),
            );
          } else {
            return Wrap(
              direction: Axis.horizontal,
              runSpacing: 20,
              spacing: 10,
              runAlignment: WrapAlignment.center,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(children: [Expanded(child: _buildCryptoInputColumn("To:", _buildResultCryptoField()))]),
                Row(children: [Expanded(child: _buildCryptoInputColumn("Rate:", _buildRatesAmountField()))]),
                Row(children: [Expanded(child: _buildCalculatedResult())]),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildCryptoInputColumn(String label, Widget amountField) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        amountField,
      ],
    );
  }

  Widget _buildRatesAmountField() {
    return WidgetsFieldsAmount(
      title: 'Rate',
      helperText: 'e.g., 10.5',
      allowReverse: true,
      allowRate: ratesAllow,
      onRetrievingRate: (void Function(String value, String helperText) updateState) {
        // Store the callback to act as promise contract!
        ratesStateUpdater = updateState;
        ratesStateUpdater?.call("", "Retrieving rate...");
        ratesGetRate();
      },
      onChanged: (value) {
        // Nullify the promise contract!
        ratesStateUpdater = null;

        if (_debounce?.isActive ?? false) _debounce!.cancel();

        _debounce = Timer(const Duration(milliseconds: 100), () {
          setState(() {
            ratesAmount = value;
          });
        });
      },
    );
  }

  Widget _buildResultCryptoField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: null,
      onSelected: (id) => setState(() {
        ratesTarget = id;
      }),
    );
  }

  Widget _buildCalculatedResult() {
    final double source = _sourceAmount;
    final double entryRate = ratesAmount == null ? 0.0 : double.tryParse(ratesAmount!) ?? 0;
    double resultValue = source * entryRate;

    final String targetSymbol = ratesTarget != null ? _cryptoController.getSymbol(ratesTarget!) ?? "" : "";

    return _buildCryptoInputColumn(
      "Result:",
      TextField(
        controller: TextEditingController(
          text: (source <= 0 || entryRate <= 0) ? "" : "${Utils.formatSmartDouble(resultValue)} $targetSymbol",
        ),
        readOnly: true,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
