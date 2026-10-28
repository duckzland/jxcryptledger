import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../mixins/rateable.dart';
import '../../../mixins/selectable_table.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/context_menu.dart';
import '../../../widgets/dialogs/alert.dart';
import '../../../widgets/fields/accent_colors.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/fields/crypto_search.dart';
import '../../../widgets/fields/textarea.dart';
import '../../../widgets/header.dart';
import '../../../widgets/notify.dart';
import '../../../widgets/text/selectable.dart';
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
  CryptosController get _cryptoController => CoreLocator.getit<CryptosController>();
  TransactionsController get _txController => CoreLocator.getit<TransactionsController>();

  final _calc = TransactionCalculation();

  final _formKey = GlobalKey<FormState>();

  late String _selectedSymbol;
  late Decimal _sourceAmount;
  late List<TransactionsModel> txs;

  late TextEditingController rateController;
  late TextEditingController resultController;
  late TextEditingController fromController;
  late TextEditingController toController;

  Decimal _fromAmount = Decimal.zero;
  Decimal _toAmount = Decimal.zero;

  Color? _accentColor;
  String? _noteEntry;

  bool _isReversed = false;
  bool _showNotes = false;
  bool _useBalanceMode = false;
  bool _isProcessing = false;

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

    rateController = TextEditingController();
    resultController = TextEditingController();
    fromController = TextEditingController();
    toController = TextEditingController();

    _selectedSymbol = _cryptoController.getSymbol(widget.srId) ?? 'Unknown Coin';
    _sourceAmount = _calc.totalActiveBalance(txs);

    for (final tx in txs) {
      selectableSetSelected(tx.uuid, true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    rateController.dispose();
    resultController.dispose();
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  @override
  void rateableGetCallback(bool hasNewRate) {
    _updateResult(rateableAmount);
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
            spacing: 16,
            children: [
              if (txs.isNotEmpty)
                Row(
                  spacing: 6,
                  children: [
                    Text("Trading Transactions", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                    Spacer(),
                    WidgetsButtonsAction(
                      icon: Icons.account_balance_wallet_outlined,
                      iconSize: 14,
                      padding: EdgeInsets.all(10),
                      minimumSize: Size(40, 40),
                      tooltip: _useBalanceMode ? "Show rate mode" : "Show custom balance",
                      onPressed: (s) {
                        setState(() {
                          _useBalanceMode = !_useBalanceMode;
                          if (_useBalanceMode && fromController.text.isEmpty) {
                            fromController.text = Utils.formatSmartDecimal(_sourceAmount, smartDecimal: false, maxDecimals: 18);
                            _fromAmount = _sourceAmount;
                          }
                        });

                        if (_useBalanceMode) {
                          s.action();
                        } else {
                          s.normal();
                        }
                      },
                      evaluator: (s) => _isProcessing
                          ? s.disable()
                          : _useBalanceMode
                          ? s.action()
                          : s.normal(),
                    ),
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
                      evaluator: (s) => _isProcessing
                          ? s.disable()
                          : _showNotes
                          ? s.action()
                          : s.normal(),
                    ),
                  ],
                ),
              if (txs.isNotEmpty) _buildForm(),
              if (txs.isNotEmpty) Column(spacing: 4, children: [_buildTable(), _buildTotal()]),
              if (txs.isEmpty) Text("No transactions to trade", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              Padding(
                padding: EdgeInsets.only(top: 15.0, bottom: 5),
                child: Wrap(
                  direction: Axis.horizontal,
                  runSpacing: 20,
                  spacing: 10,
                  runAlignment: WrapAlignment.center,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    WidgetsButtonsAction(
                      label: (txs.isNotEmpty) ? 'Cancel' : 'Close',
                      onPressed: (_) => Navigator.pop(context),
                      evaluator: (s) {
                        _isProcessing ? s.disable() : s.normal();
                      },
                    ),
                    if (txs.isNotEmpty)
                      WidgetsDialogsAlert(
                        label: "Trade",
                        padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                        filledMode: true,
                        dialogTitle: "Trade Confirmation",
                        dialogMessage: "This action cannot be undone.",
                        dialogCancelLabel: "Cancel",
                        dialogConfirmLabel: "Trade",
                        showMessage: false,
                        initialState: WidgetsButtonActionState.action,
                        tooltip: "Trade all selected transactions",
                        evaluator: (s) {
                          if (_isProcessing) {
                            s.progress();
                            return;
                          }
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

    final Decimal rate = rateableAmount == null ? Decimal.zero : rateableParseToDecimal(rateableAmount!, reverse: _isReversed);
    final String targetSymbol = rateableTarget != null ? _cryptoController.getSymbol(rateableTarget!) ?? "" : "";

    final bool showRate = !_useBalanceMode && rate > Decimal.zero && targetSymbol.isNotEmpty;
    final bool showAmount = _useBalanceMode && targetSymbol.isNotEmpty && _toAmount > Decimal.zero && _fromAmount > Decimal.zero;
    final Decimal customFrom = _fromAmount;
    final Decimal customTo = _toAmount;
    final selectedTxs = txs.where((tx) => selectableIsSelected(tx.uuid) && (tx.isActive || tx.isPartial)).toList();
    final fromAllocations = _calc.spreadAmount(customFrom, selectedTxs);
    final toAllocations = _calc.spreadAmount(customTo, selectedTxs);

    for (final tx in txs) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';
      final bool selected = selectableIsSelected(tx.uuid) && (tx.isActive || tx.isPartial);
      final Decimal fromAmount = _useBalanceMode ? fromAllocations[tx.uuid] ?? Decimal.zero : Decimal.zero;
      final Decimal amount = _useBalanceMode ? toAllocations[tx.uuid] ?? Decimal.zero : Math.multiply(tx.rrAmount, rate);

      rows.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': '${tx.srAmountTextRaw} $sourceSymbol → ${tx.rrAmountTextRaw} $resultSymbol',
        'balance': showAmount
            ? '${Utils.formatSmartDecimal(fromAmount, smartDecimal: false, maxDecimals: 18)} $resultSymbol'
            : '${tx.balanceTextRaw} $resultSymbol',
        'rate': rateableAmount,
        'amount': amount,
        'selected': selected,
        'tx': tx,
        'uuid': tx.uuid,
      });
    }

    final rateText = WidgetsTextSelectable(rateableAmount ?? "");
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
          DataColumn2(label: Text('Date '), fixedWidth: 100),
          DataColumn2(label: Text('Transactions '), size: ColumnSize.M),
          DataColumn2(label: Text(showAmount || showRate ? 'From ' : 'Balance '), size: ColumnSize.M),
          if (showRate)
            DataColumn2(
              label: WidgetsHeader(
                title: "Rate ",
                subtitle: _isReversed ? "$targetSymbol - $_selectedSymbol" : "$_selectedSymbol - $targetSymbol",
              ),
              size: ColumnSize.M,
            ),
          if (showRate || showAmount) DataColumn2(label: Text('To '), size: ColumnSize.M),
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
                        _updateResult(rateableAmount);
                        _buildResultAmountField();
                      });
                    }
                  : null,
              cells: [
                DataCell(WidgetsTextSelectable(r['date'] ?? '')),
                DataCell(WidgetsTextSelectable(r['transaction'] ?? '')),
                DataCell(WidgetsTextSelectable(r['balance'] ?? '')),
                if (showRate) DataCell(rateText),
                if (showRate || showAmount)
                  DataCell(
                    WidgetsTextSelectable(
                      r['selected'] == true && targetSymbol.isNotEmpty
                          ? '${Utils.formatSmartDecimal(r['amount'] ?? Decimal.zero, smartDecimal: false)} $targetSymbol'
                          : '',
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotal() {
    final Decimal rate = rateableAmount == null ? Decimal.zero : rateableParseToDecimal(rateableAmount!, reverse: _isReversed);
    final Decimal source = _useBalanceMode ? _fromAmount : _sourceAmount;
    final Decimal resultValue = _useBalanceMode ? _toAmount : Math.multiply(source, rate);
    final String targetSymbol = rateableTarget != null ? _cryptoController.getSymbol(rateableTarget!) ?? "" : "";

    final bool showRate = !_useBalanceMode && rate > Decimal.zero && targetSymbol.isNotEmpty;
    final bool showAmount = _useBalanceMode && targetSymbol.isNotEmpty && _toAmount > Decimal.zero && _fromAmount > Decimal.zero;

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
          DataColumn2(label: Text('        Total'), fixedWidth: 130),
          DataColumn2(label: Text(' '), size: ColumnSize.M),
          DataColumn2(
            label: WidgetsTextSelectable('${Utils.formatSmartDecimal(source, smartDecimal: false)} $_selectedSymbol'),
            size: ColumnSize.M,
          ),
          if (showRate) DataColumn2(label: Text(''), size: ColumnSize.M),
          if (showRate || showAmount)
            DataColumn2(
              label: WidgetsTextSelectable('${Utils.formatSmartDecimal(resultValue, smartDecimal: false)} $targetSymbol'),
              size: ColumnSize.M,
            ),
        ],
        rows: [],
      ),
    );
  }

  Widget _buildForm() {
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
                        child: WidgetsHeader(
                          subtitle: "From:",
                          subtitleFontSize: 13,
                          spacing: 10,
                          child: _useBalanceMode ? _buildCustomFromAmountField() : _buildFromAmountField(),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 40),
                        child: Icon(_useBalanceMode ? Icons.arrow_forward : Icons.clear, size: 24),
                      ),
                      Expanded(
                        child: WidgetsHeader(
                          subtitle: "To:",
                          subtitleFontSize: 13,
                          spacing: 10,
                          child: _useBalanceMode ? _buildCustomToAmountField() : _buildRatesAmountField(),
                        ),
                      ),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 5, vertical: 40)),
                      Expanded(
                        child: WidgetsHeader(subtitle: " ", subtitleFontSize: 13, spacing: 10, child: _buildCoinSelectField()),
                      ),
                      if (!_useBalanceMode) ...[
                        Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 40), child: Icon(Icons.arrow_forward, size: 24)),
                        Expanded(child: _buildResultAmountField()),
                      ],
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
                      child: WidgetsHeader(
                        subtitle: "From:",
                        subtitleFontSize: 13,
                        spacing: 10,
                        child: _useBalanceMode ? _buildCustomFromAmountField() : _buildFromAmountField(),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: WidgetsHeader(
                        subtitle: "To:",
                        subtitleFontSize: 13,
                        spacing: 10,
                        child: _useBalanceMode ? _buildCustomToAmountField() : _buildRatesAmountField(),
                      ),
                    ),
                  ],
                ),
                Row(children: [Expanded(child: _buildCoinSelectField())]),
                if (!_useBalanceMode) Row(children: [Expanded(child: _buildResultAmountField())]),
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
      contextMenuBuilder: (context, editableTextState) {
        return WidgetsContextMenu(
          anchor: editableTextState.contextMenuAnchors.primaryAnchor,
          buttonItems: editableTextState.contextMenuButtonItems,
        );
      },
      controller: TextEditingController(
        text: selectableHasSelectedRows()
            ? "${Utils.formatSmartDecimal(_sourceAmount, smartDecimal: false)} $_selectedSymbol"
            : "No transaction selected",
      ),
      readOnly: true,
      style: TextStyle(fontSize: 16),
    );
  }

  Widget _buildCustomFromAmountField() {
    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'e.g., 10.5',
      enabled: !_isProcessing,
      suffixText: _selectedSymbol,
      useMax: _sourceAmount,
      controller: fromController,
      disposeController: false,
      onChanged: (value) {
        setState(() => _fromAmount = Utils.parseDecimal(value));
      },
    );
  }

  Widget _buildCustomToAmountField() {
    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'e.g., 10.5',
      enabled: !_isProcessing,
      controller: toController,
      disposeController: false,
      onChanged: (value) {
        setState(() => _toAmount = Utils.parseDecimal(value));
      },
    );
  }

  Widget _buildRatesAmountField() {
    return WidgetsFieldsAmount(
      title: 'Rate',
      helperText: 'e.g., 10.5',
      enabled: !_isProcessing,
      allowReverse: true,
      allowRate: rateableAllow,
      controller: rateController,
      disposeController: false,
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
          _debounce = Timer(Duration(milliseconds: 100), () {
            setState(() {
              rateableAmount = value;
              _updateResult(rateableAmount);
            });
          });
        }
      },
      onReversing: () {
        setState(() {
          _isReversed = !_isReversed;
          rateableAmount = rateableParseToString(rateableAmount!, reverse: true);
          _updateResult(rateableAmount);
        });
      },
    );
  }

  Widget _buildCoinSelectField() {
    return WidgetsFieldsCryptoSearch(
      labelText: 'Coin',
      initialValue: null,
      enabled: !_isProcessing,
      onSelected: (id) => setState(() {
        rateableTarget = id;
      }),
    );
  }

  Widget _buildNotesField() {
    return WidgetsFieldsTextarea(
      title: 'Trading Notes',
      helperText: 'Add notes..',
      enabled: !_isProcessing,
      maxLines: 3,
      onChanged: (value) {
        setState(() => _noteEntry = value);
      },
    );
  }

  Widget _buildColorsField() {
    return WidgetsFieldsAccentColors(
      enabled: !_isProcessing,
      onChange: (value) {
        setState(() => _accentColor = value);
      },
    );
  }

  Widget _buildResultAmountField() {
    return WidgetsHeader(
      subtitle: "Result:",
      subtitleFontSize: 13,
      spacing: 10,
      child: WidgetsFieldsAmount(
        title: 'Amount',
        suffixText: rateableTarget != null ? _cryptoController.getSymbol(rateableTarget!) ?? "" : "",
        helperText: "",
        controller: resultController,
        disposeController: false,
        onChanged: (value) {
          _updateRate(value);
          setState(() {});
        },
      ),
    );
  }

  void _updateSource() {
    _sourceAmount = _selectedBalance();
  }

  Decimal _selectedBalance() {
    final selectedTxIds = selectableGetSelectedRows();
    final selectedTxs = txs.where((tx) => selectedTxIds.contains(tx.uuid) && (tx.isActive || tx.isPartial)).toList();
    return _calc.totalActiveBalance(selectedTxs);
  }

  void _updateRate(String totalAmount) {
    _updateSource();

    final Decimal entryRate = rateableAmount == null ? Decimal.zero : rateableParseToDecimal(rateableAmount!, reverse: _isReversed);

    final checkValue = Math.multiply(_sourceAmount, entryRate);
    final amount = rateableParseToDecimal(totalAmount);

    if (checkValue != amount) {
      final newRate = Math.divide(amount, _sourceAmount);
      rateableAmount = (newRate <= Decimal.zero)
          ? null
          : rateableParseToString(
              Utils.formatSmartDecimal(newRate, smartDecimal: false, maxDecimals: 18).replaceAll(",", ""),
              reverse: _isReversed,
            );

      rateController.text = rateableAmount ?? "";
    }
  }

  void _updateResult(String? rateText) {
    _updateSource();

    final Decimal entryRate = rateableParseToDecimal(rateText ?? "", reverse: _isReversed);
    final Decimal resultValue = Math.multiply(_sourceAmount, entryRate);

    resultController.text = resultValue <= Decimal.zero ? "" : Utils.formatSmartDecimal(resultValue, smartDecimal: false);
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final Decimal rate = rateableAmount == null ? Decimal.zero : rateableParseToDecimal(rateableAmount!, reverse: _isReversed);
    final Decimal customFrom = _fromAmount;
    final Decimal customTo = _toAmount;
    final stxs = [...txs];

    final selectedTxIds = selectableGetSelectedRows();
    stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid) && (tx.isActive || tx.isPartial));

    if (stxs.isEmpty || (_useBalanceMode ? customFrom <= Decimal.zero || customTo <= Decimal.zero : rate <= Decimal.zero)) return;

    final Decimal selectedBalance = _calc.totalActiveBalance(stxs);
    if (_useBalanceMode && (selectedBalance <= Decimal.zero || customFrom > selectedBalance)) return;
    final fromAllocations = _calc.spreadAmount(customFrom, stxs);
    final toAllocations = _calc.spreadAmount(customTo, stxs);

    setState(() {
      _isProcessing = true;
    });

    bool completed = true;

    for (final tx in stxs) {
      final Decimal sourceAmount = _useBalanceMode ? fromAllocations[tx.uuid] ?? Decimal.zero : tx.balance;
      final Decimal amount = _useBalanceMode ? toAllocations[tx.uuid] ?? Decimal.zero : Math.multiply(tx.balance, rate);
      final meta = Map<String, dynamic>.from(tx.meta);

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
          srAmount: sourceAmount,
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
        completed = false;
        widget.onSave?.call(e);
        break;
      } catch (e) {
        completed = false;
        widget.onSave?.call(e);
        break;
      }
    }

    if (completed) {
      if (txs.isEmpty) {
        widget.onSave?.call(null);
      } else {
        widgetsNotifySuccess("Trade completed successfully.");
      }
    }

    if (txs.isNotEmpty) {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}
