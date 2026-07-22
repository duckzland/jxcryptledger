import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../mixins/rateable.dart';
import '../../../mixins/selectable_table.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/fields/accent_colors.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/fields/textarea.dart';
import '../../../widgets/header.dart';
import '../../../widgets/notify.dart';
import '../../cryptos/controller.dart';
import '../calculations.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsDialogsBatchTrade extends StatefulWidget {
  final int srId;
  final List<TransactionsModel>? transactions;
  final void Function(Object? error)? onSave;

  const TransactionsDialogsBatchTrade({super.key, required this.srId, required this.onSave, this.transactions});

  @override
  State<TransactionsDialogsBatchTrade> createState() => _TransactionsDialogsBatchTradeState();
}

class _TransactionsDialogsBatchTradeState extends State<TransactionsDialogsBatchTrade>
    with MixinsState, MixinsTable, MixinsSelectableTable, MixinsRateable<TransactionsDialogsBatchTrade> {
  CryptosController get _cryptoController => locator<CryptosController>();
  TransactionsController get _txController => locator<TransactionsController>();

  final _calc = TransactionCalculation();

  final _formKey = GlobalKey<FormState>();

  late String _selectedSymbol;
  late double _sourceAmount;
  late List<TransactionsModel> txs;

  Color? _accentColor;
  String? _noteEntry;

  bool _isReversed = false;
  bool _showNotes = false;

  Timer? _debounce;

  @override
  double get tableHeightOffset => _showNotes ? 360 : 290;

  @override
  double get tableHeadingHeightOffset => 0;

  @override
  void initState() {
    super.initState();
    rateableSource = widget.srId;

    txs = List.from(widget.transactions ?? []);
    txs.retainWhere((tx) => tx.isActive || tx.isPartial);

    _selectedSymbol = _cryptoController.getSymbol(widget.srId) ?? 'Unknown Coin';
    _sourceAmount = _calc.totalActiveBalance(txs);

    for (final tx in txs) {
      selectableSetSelected(tx.uuid, true);
    }
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
      constraints: const BoxConstraints(maxWidth: 1200),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              if (txs.isNotEmpty)
                Row(
                  children: [
                    Text("Trading Transactions", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                    Spacer(),
                    WidgetsButtonsAction(
                      icon: Icons.note_add,
                      iconSize: 14,
                      padding: EdgeInsets.all(10),
                      minimumSize: Size(40, 40),
                      tooltip: _showNotes ? "Hide notes" : "Show Notes",
                      onPressed: (s) {
                        setState(() {
                          _showNotes = !_showNotes;
                        });

                        if (_showNotes) {
                          s.action();
                        } else {
                          s.normal();
                        }
                      },
                    ),
                  ],
                ),
              if (txs.isNotEmpty) _buildCalculator(),
              if (txs.isNotEmpty) Column(spacing: 4, children: [_buildTable(), _buildTotal()]),
              if (txs.isEmpty) const Text("No transactions to trade", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              Padding(
                padding: const EdgeInsets.only(top: 15.0, bottom: 5),
                child: Wrap(
                  direction: Axis.horizontal,
                  runSpacing: 20,
                  spacing: 10,
                  runAlignment: WrapAlignment.center,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    WidgetsButtonsAction(label: (txs.isNotEmpty) ? 'Cancel' : 'Close', onPressed: (_) => Navigator.pop(context)),
                    if (txs.isNotEmpty)
                      WidgetsDialogsAlert(
                        label: "Trade",
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        filledMode: true,
                        dialogTitle: "Trade Confirmation",
                        dialogMessage: "This action cannot be undone.",
                        dialogCancelLabel: "Cancel",
                        dialogConfirmLabel: "Trade",
                        showMessage: false,
                        initialState: WidgetsButtonActionState.action,
                        tooltip: "Trade all selected transactions",
                        evaluator: (s) {
                          if (selectableHasSelectedRows()) {
                            s.action();
                          } else {
                            s.disable();
                          }
                        },
                        actionCompleteCallback: _handleSave,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    rows = <Map<String, dynamic>>[];

    final double rate = rateableAmount == null ? 0.0 : rateableParseToDouble(rateableAmount!, reverse: _isReversed);
    final String targetSymbol = rateableTarget != null ? _cryptoController.getSymbol(rateableTarget!) ?? "" : "";

    final bool showRate = rate > 0 && targetSymbol.isNotEmpty;

    for (final tx in txs) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';
      final double amount = Math.multiply(tx.rrAmount, rate);

      rows.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': '${tx.srAmountTextRaw} $sourceSymbol → ${tx.rrAmountTextRaw} $resultSymbol',
        'balance': '${tx.balanceTextRaw} $resultSymbol',
        'rate': rateableAmount,
        'amount': amount,
        'tx': tx,
        'uuid': tx.uuid,
      });
    }

    final rateText = Text(rateableAmount ?? "");
    final checkboxTheme = Theme.of(context).checkboxTheme;

    return SizedBox(
      width: double.infinity,
      height: tableCalculateAdjustedMaxHeight(),
      child: DataTable2(
        headingCheckboxTheme: checkboxTheme,
        datarowCheckboxTheme: checkboxTheme,
        showHeadingCheckBox: true,
        showCheckboxColumn: true,
        minWidth: 800,
        columnSpacing: 12,
        horizontalMargin: 12,
        headingRowHeight: tableHeadingHeight,
        dataRowHeight: tableRowHeight,
        isHorizontalScrollBarVisible: false,
        columns: [
          const DataColumn2(label: Text('Date '), fixedWidth: 100),
          const DataColumn2(label: Text('Transactions '), size: ColumnSize.M),
          const DataColumn2(label: Text('Balance '), size: ColumnSize.M),
          if (showRate) const DataColumn2(label: Text('Rate '), size: ColumnSize.M),
          if (showRate) const DataColumn2(label: Text('Amount '), size: ColumnSize.M),
        ],
        rows: [
          ...rows.map((r) {
            final tx = r['tx'] as TransactionsModel;
            final canSelect = tx.isActive || tx.isPartial;
            return DataRow(
              selected: canSelect ? selectableIsSelected(r['uuid']) : false,
              onSelectChanged: canSelect
                  ? (v) {
                      setState(() {
                        selectableSetSelected(r['uuid'], v!);
                        _buildCalculatedResult();
                      });
                    }
                  : null,
              cells: [
                DataCell(Text(r['date'] ?? '')),
                DataCell(Text(r['transaction'] ?? '')),
                DataCell(Text(r['balance'] ?? '')),
                if (showRate) DataCell(rateText),
                if (showRate) DataCell(Text('${Utils.formatSmartDouble(r['amount'] ?? 0, smartDecimal: false)} $targetSymbol')),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotal() {
    final double rate = rateableAmount == null ? 0.0 : rateableParseToDouble(rateableAmount!, reverse: _isReversed);
    final double source = _sourceAmount;
    final double resultValue = Math.multiply(source, rate);
    final String targetSymbol = rateableTarget != null ? _cryptoController.getSymbol(rateableTarget!) ?? "" : "";

    final bool showRate = rate > 0 && targetSymbol.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: AppTheme.tableDataRowMinHeight,
      child: DataTable2(
        minWidth: 800,
        columnSpacing: 12,
        horizontalMargin: 12,
        headingRowHeight: AppTheme.tableDataRowMinHeight,
        dataRowHeight: AppTheme.tableDataRowMinHeight,
        isHorizontalScrollBarVisible: false,
        columns: [
          const DataColumn2(label: Text('        Total'), fixedWidth: 130),
          const DataColumn2(label: Text(' '), size: ColumnSize.M),
          DataColumn2(label: Text('${Utils.formatSmartDouble(_sourceAmount, smartDecimal: false)} $_selectedSymbol'), size: ColumnSize.M),
          if (showRate) const DataColumn2(label: Text(''), size: ColumnSize.M),
          if (showRate)
            DataColumn2(label: Text('${Utils.formatSmartDouble(resultValue, smartDecimal: false)} $targetSymbol'), size: ColumnSize.M),
        ],
        rows: [],
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
            return Column(
              spacing: 10,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: hasError ? 108 : 90,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: WidgetsHeader(subtitle: "From:", subtitleFontSize: 13, spacing: 10, child: _buildFromAmountField()),
                      ),

                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 40), child: Icon(Icons.clear, size: 24)),

                      Expanded(
                        child: WidgetsHeader(subtitle: "To:", subtitleFontSize: 13, spacing: 10, child: _buildRatesAmountField()),
                      ),

                      const Padding(padding: EdgeInsets.symmetric(horizontal: 5, vertical: 40)),

                      Expanded(
                        child: WidgetsHeader(subtitle: " ", subtitleFontSize: 13, spacing: 10, child: _buildResultCryptoField()),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 40),
                        child: Icon(Icons.arrow_forward, size: 24),
                      ),

                      Expanded(child: _buildCalculatedResult()),
                    ],
                  ),
                ),
                if (_showNotes)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      Flexible(flex: 2, child: _buildNotesPanel()),
                      Flexible(flex: 2, child: _buildAccentColorsPanel()),
                    ],
                  ),
              ],
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
                Row(
                  children: [
                    Expanded(
                      child: WidgetsHeader(subtitle: "From:", subtitleFontSize: 13, spacing: 10, child: _buildFromAmountField()),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: WidgetsHeader(subtitle: "To:", subtitleFontSize: 13, spacing: 10, child: _buildRatesAmountField()),
                    ),
                  ],
                ),
                Row(children: [Expanded(child: _buildResultCryptoField())]),
                Row(children: [Expanded(child: _buildCalculatedResult())]),
                if (_showNotes) Row(children: [Expanded(child: _buildAccentColorsPanel())]),
                if (_showNotes) Row(children: [Expanded(child: _buildNotesPanel())]),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildAccentColorsPanel() {
    return WidgetsHeader(subtitle: "Accent Color:", subtitleFontSize: 13, spacing: 10, child: _buildColorsField());
  }

  Widget _buildNotesPanel() {
    return WidgetsHeader(subtitle: "Notes:", subtitleFontSize: 13, spacing: 10, child: _buildNotesField());
  }

  Widget _buildFromAmountField() {
    return TextField(
      controller: TextEditingController(
        text: selectableHasSelectedRows()
            ? "${Utils.formatSmartDouble(_sourceAmount, smartDecimal: false)} $_selectedSymbol"
            : "No transaction selected",
      ),
      readOnly: true,
      style: const TextStyle(fontSize: 16),
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
        rateableGetRate(reversed: _isReversed);
      },
      onChanged: (value) {
        // Nullify the promise contract!
        rateableStateUpdater = null;

        if (_debounce?.isActive ?? false) _debounce!.cancel();

        if (value != rateableAmount) {
          _debounce = Timer(const Duration(milliseconds: 100), () {
            setState(() {
              rateableAmount = value;
            });
          });
        }
      },
      onReversing: () {
        setState(() {
          _isReversed = !_isReversed;

          rateableAmount = rateableParseToString(rateableAmount!, reverse: true);
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

  Widget _buildNotesField() {
    return WidgetsFieldsTextarea(
      title: 'Trading Notes',
      helperText: 'Add notes..',
      maxLines: 3,
      onChanged: (value) {
        setState(() => _noteEntry = value);
      },
    );
  }

  Widget _buildColorsField() {
    return WidgetsFieldsAccentColors(
      onChange: (value) {
        setState(() => _accentColor = value);
      },
    );
  }

  Widget _buildCalculatedResult() {
    final stxs = [...txs];

    final selectedTxIds = selectableGetSelectedRows();
    stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));

    final atxs = stxs.where((tx) => tx.isActive || tx.isPartial).toList();
    _sourceAmount = _calc.totalActiveBalance(atxs);

    final double entryRate = rateableAmount == null ? 0.0 : rateableParseToDouble(rateableAmount!, reverse: _isReversed);
    final double resultValue = Math.multiply(_sourceAmount, entryRate);

    final String targetSymbol = rateableTarget != null ? _cryptoController.getSymbol(rateableTarget!) ?? "" : "";

    return WidgetsHeader(
      subtitle: "Result:",
      subtitleFontSize: 13,
      spacing: 10,
      child: TextField(
        controller: TextEditingController(
          text: (_sourceAmount <= 0 || entryRate <= 0) ? "" : "${Utils.formatSmartDouble(resultValue, smartDecimal: false)} $targetSymbol",
        ),
        readOnly: true,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final double rate = rateableAmount == null ? 0.0 : rateableParseToDouble(rateableAmount!, reverse: _isReversed);
    final stxs = [...txs];

    final selectedTxIds = selectableGetSelectedRows();
    stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid) && (tx.isActive || tx.isPartial));

    if (stxs.isEmpty || rate <= 0) return;

    for (final tx in stxs) {
      final double amount = Math.multiply(tx.balance, rate);
      final meta = tx.meta;

      if (_noteEntry != null) {
        meta['trading_notes'] = _noteEntry;
      }

      if (_accentColor != null) {
        meta['accent_color'] = _accentColor!.toARGB32().toRadixString(16).padLeft(8, '0');
      }

      try {
        final child = TransactionsModel(
          tid: _txController.generateId(),
          rid: tx.isRoot ? tx.tid : tx.rid,
          pid: tx.tid,
          srId: tx.rrId,
          srAmount: tx.balance,
          rrId: rateableTarget ?? 0,
          rrAmount: amount,
          balance: amount,
          status: TransactionStatus.active.index,
          timestamp: Utils.dateToTimestamp(DateTime.now()),
          closable: false,
          meta: meta,
        );
        await _txController.add(child);
        txs.remove(tx);
        selectableSetSelected(tx.uuid, false);
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
      widgetsNotifySuccess("Trade completed successfully.");
      setState(() {});
    }
  }
}
