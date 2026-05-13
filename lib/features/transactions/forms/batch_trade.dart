import 'dart:async';
import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../mixins/rateable.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsFormsBatchTrade extends StatefulWidget {
  final int srId;
  final double totalAmount;
  final List<TransactionsModel>? transactions;
  final void Function(Object? error)? onSave;

  const TransactionsFormsBatchTrade({super.key, required this.srId, required this.totalAmount, required this.onSave, this.transactions});

  @override
  State<TransactionsFormsBatchTrade> createState() => _TransactionsFormsBatchTradeState();
}

class _TransactionsFormsBatchTradeState extends State<TransactionsFormsBatchTrade> with MixinsRateable<TransactionsFormsBatchTrade> {
  CryptosController get _cryptoController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  final _formKey = GlobalKey<FormState>();

  late String _selectedSymbol;
  late double _sourceAmount;
  late List<TransactionsModel> txs;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    rateableSource = widget.srId;

    _selectedSymbol = _cryptoController.getSymbol(widget.srId) ?? 'Unknown Coin';
    _sourceAmount = widget.totalAmount;
    txs = List.from(widget.transactions ?? []);
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
                if (txs.isNotEmpty)
                  Text(
                    "Trade For ${Utils.formatSmartDouble(_sourceAmount)} $_selectedSymbol",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                if (txs.isNotEmpty)
                  WidgetsPanel(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 0, children: [_buildCalculator()]),
                  ),
                if (txs.isNotEmpty)
                  WidgetsPanel(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 0, children: [_buildTable()]),
                  ),
                if (txs.isEmpty) Text("No transactions to trade", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),

                WidgetsPanel(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    direction: Axis.horizontal,
                    runSpacing: 20,
                    spacing: 10,
                    runAlignment: WrapAlignment.center,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      WidgetsButton(label: (txs.isNotEmpty) ? 'Cancel' : 'Close', onPressed: (_) => Navigator.pop(context)),
                      if (txs.isNotEmpty)
                        WidgetsDialogsAlert(
                          label: "Trade",
                          padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          persistBg: true,
                          dialogTitle: "Trade Confirmation",
                          dialogMessage: "This action cannot be undone.",
                          dialogCancelLabel: "Cancel",
                          dialogConfirmLabel: "Trade",
                          showMessage: false,
                          initialState: WidgetsButtonActionState.action,
                          tooltip: "Trade all selected transactions",
                          evaluator: (s) {},
                          actionCompleteCallback: _handleSave,
                        ),
                    ],
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
    final double rate = rateableAmount == null ? 0.0 : double.tryParse(rateableAmount!) ?? 0;
    final double source = _sourceAmount;
    final double entryRate = rateableAmount == null ? 0.0 : double.tryParse(rateableAmount!) ?? 0;
    double resultValue = Math.multiply(source, entryRate);
    final String targetSymbol = rateableTarget != null ? _cryptoController.getSymbol(rateableTarget!) ?? "" : "";

    final bool showRate = rate > 0 && targetSymbol.isNotEmpty;

    for (final tx in txs) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';
      final double amount = Math.multiply(tx.rrAmount, rate);

      rows.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': '${tx.srAmountText} $sourceSymbol → ${tx.balanceText} $resultSymbol',
        'rate': rateableAmount,
        'amount': amount,
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
            if (showRate) DataColumn2(label: Text('Rate '), size: ColumnSize.M),
            if (showRate) DataColumn2(label: Text('Amount '), size: ColumnSize.M),
          ],
          rows: [
            ...rows.map((r) {
              return DataRow(
                cells: [
                  DataCell(Text(r['date'] ?? '')),
                  DataCell(Text(r['transaction'] ?? '')),
                  if (showRate) DataCell(Text('${r['rate'] ?? ''}')),
                  if (showRate) DataCell(Text('${Utils.formatSmartDouble(r['amount'] ?? 0)} $targetSymbol')),
                ],
              );
            }),

            DataRow(
              color: WidgetStateProperty.all(AppTheme.headerBg),
              cells: [
                DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('${Utils.formatSmartDouble(_sourceAmount)} $_selectedSymbol', style: TextStyle(fontWeight: FontWeight.bold))),
                if (showRate) DataCell(Text('')),
                if (showRate)
                  DataCell(Text('${Utils.formatSmartDouble(resultValue)} $targetSymbol', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculator() {
    bool hasError = false;
    if (_formKey.currentState != null) {
      hasError = !_formKey.currentState!.validate();
    }
    return Form(
      key: _formKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return SizedBox(
              width: double.infinity,
              height: hasError ? 108 : 90,
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
      allowRate: rateableAllow,
      onRetrievingRate: (void Function(String value, String helperText) updateState) {
        // Store the callback to act as promise contract!
        rateableStateUpdater = updateState;
        rateableStateUpdater?.call("", "Retrieving rate...");
        rateableGetRate();
      },
      onChanged: (value) {
        // Nullify the promise contract!
        rateableStateUpdater = null;

        if (_debounce?.isActive ?? false) _debounce!.cancel();

        _debounce = Timer(const Duration(milliseconds: 100), () {
          setState(() {
            rateableAmount = value;
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
        rateableTarget = id;
      }),
    );
  }

  Widget _buildCalculatedResult() {
    final double source = _sourceAmount;
    final double entryRate = rateableAmount == null ? 0.0 : double.tryParse(rateableAmount!) ?? 0;
    double resultValue = Math.multiply(source, entryRate);

    final String targetSymbol = rateableTarget != null ? _cryptoController.getSymbol(rateableTarget!) ?? "" : "";

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

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final double rate = rateableAmount == null ? 0.0 : double.tryParse(rateableAmount!) ?? 0;

    if (txs.isEmpty || rate <= 0) return;

    for (final tx in List.from(txs)) {
      final double amount = Math.multiply(tx.rrAmount, rate);
      try {
        final child = TransactionsModel(
          tid: _txController.generateId(),
          rid: tx.isRoot ? tx.tid : tx.rid,
          pid: tx.tid,
          srId: tx.rrId,
          srAmount: tx.rrAmount,
          rrId: rateableTarget ?? 0,
          rrAmount: amount,
          balance: amount,
          status: TransactionStatus.active.index,
          timestamp: Utils.dateToTimestamp(DateTime.now()),
          closable: false,
          meta: tx.meta,
        );
        await _txController.add(child);
        txs.remove(tx);
      } on ValidationException catch (e) {
        widget.onSave?.call(e);
        return;
      } catch (e) {
        widget.onSave?.call(e);
        return;
      }
    }

    if (txs.isEmpty) {
      widget.onSave?.call(null);
    } else {
      setState(() {});
    }
  }
}
