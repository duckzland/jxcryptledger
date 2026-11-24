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
import '../../../widgets/table/virtualized/single.dart';
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
    with
        MixinsState,
        MixinsTable<TransactionsDialogsBatchTrade>,
        MixinsSelectableTable<TransactionsDialogsBatchTrade>,
        MixinsRateable<TransactionsDialogsBatchTrade> {
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
  bool _takeProfit = false;

  Color? _accentColor;
  String _targetSymbol = "";
  String? _noteEntry;

  bool _isReversed = false;
  bool _showNotes = false;
  bool _showRate = false;
  bool _showAmount = false;
  bool _useBalanceMode = false;
  bool _isProcessing = false;
  bool _isExiting = false;

  Timer? _debounce;

  final ScrollController tableScrollController = ScrollController();

  @override
  double get tableHeightOffset => _showNotes ? 400 : 360;

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
    _sourceAmount = Utils.sanitizeFractalDecimal(_calc.totalActiveBalance(txs));

    for (final tx in txs) {
      selectableSetSelected(tx.uuid, true);
    }

    _updateTableState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    rateController.dispose();
    resultController.dispose();
    fromController.dispose();
    toController.dispose();
    tableScrollController.dispose();
    super.dispose();
  }

  @override
  void rateableGetCallback(bool hasNewRate) {
    _updateResult(rateableAmount);
    _updateTableState();
  }

  List<Map<String, dynamic>> tablePopulateData() {
    tableData = <Map<String, dynamic>>[];

    final Decimal rate = rateableAmount == null ? Decimal.zero : rateableParseToDecimal(rateableAmount!, reverse: _isReversed);

    final selectedTxs = txs.where((tx) => selectableIsSelected(tx.uuid) && (tx.isActive || tx.isPartial)).toList();
    var fromAllocations = <String, Decimal>{};
    var toAllocations = <String, Decimal>{};

    if (_takeProfit) {
      Decimal? profitRemaining = _fromAmount;
      for (final tx in selectedTxs) {
        if (profitRemaining == null) break;

        final txProfit = Math.subtract(tx.balance, tx.rrAmount);
        if (txProfit <= Decimal.zero) continue;

        final sourceAmount = txProfit < profitRemaining ? txProfit : profitRemaining;
        fromAllocations[tx.uuid] = sourceAmount;
        profitRemaining = sourceAmount == profitRemaining ? null : Math.subtract(profitRemaining, sourceAmount);
      }
      toAllocations = _spreadByWeights(_toAmount, selectedTxs, fromAllocations);
    } else if (_useBalanceMode) {
      fromAllocations = _calc.spreadAmount(_fromAmount, selectedTxs);
      toAllocations = _calc.spreadAmount(_toAmount, selectedTxs);
    }

    for (final tx in txs) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';
      final bool selected = selectableIsSelected(tx.uuid) && (tx.isActive || tx.isPartial);
      Decimal fromAmount = Decimal.zero;
      late final Decimal amount;

      if (_takeProfit) {
        fromAmount = fromAllocations[tx.uuid] ?? Decimal.zero;
        amount = toAllocations[tx.uuid] ?? Decimal.zero;
      } else if (_useBalanceMode) {
        fromAmount = fromAllocations[tx.uuid] ?? Decimal.zero;
        amount = toAllocations[tx.uuid] ?? Decimal.zero;
      } else {
        amount = Math.multiply(tx.rrAmount, rate);
      }

      tableData.add({
        'date': tx.timestampAsFormattedDate,
        'transaction': '${tx.srAmountTextRaw} $sourceSymbol → ${tx.rrAmountTextRaw} $resultSymbol',
        'balance': _showAmount
            ? fromAmount > Decimal.zero
                  ? '${Utils.formatSmartDecimal(fromAmount, smartDecimal: false, maxDecimals: 18)} $resultSymbol'
                  : ''
            : tx.balance > Decimal.zero
            ? '${tx.balanceTextRaw} $resultSymbol'
            : '',
        'rate': rateableAmount,
        'amount': amount > Decimal.zero ? amount : null,
        'selected': selected,
        'tx': tx,
        'uuid': tx.uuid,
      });
    }

    return tableData;
  }

  List<DataColumn> tableBuildColumns() {
    tableColumns = [
      DataColumn2(label: Text('Date '), fixedWidth: 100),
      DataColumn2(label: Text('Transactions '), size: ColumnSize.M),
      DataColumn2(label: Text(_showAmount || _showRate ? 'From ' : 'Balance '), size: ColumnSize.M),
      if (_showRate)
        DataColumn2(
          label: WidgetsHeader(
            title: "Rate ",
            subtitle: _isReversed ? "$_targetSymbol - $_selectedSymbol" : "$_selectedSymbol - $_targetSymbol",
          ),
          size: ColumnSize.M,
        ),
      if (_showRate || _showAmount) DataColumn2(label: Text('To '), size: ColumnSize.M),
    ];

    return tableColumns;
  }

  DataRow tableBuildRow(Map<String, dynamic> row) {
    final tx = row['tx'] as TransactionsModel;
    final canSelect = tx.isActive || tx.isPartial;

    return DataRow(
      selected: canSelect ? selectableIsSelected(row['uuid']) : false,
      onSelectChanged: canSelect
          ? (v) {
              setState(() {
                selectableSetSelected(row['uuid'], v!);

                _sourceAmount = Utils.sanitizeFractalDecimal(_calc.totalActiveBalance(_getSelectedTransactions()));

                _updateProfit();
                _updateResult(rateableAmount);
                _buildResultAmountField();
              });
            }
          : null,
      cells: [
        DataCell(WidgetsTextSelectable(row['date'] ?? '')),
        DataCell(WidgetsTextSelectable(row['transaction'] ?? '')),
        DataCell(WidgetsTextSelectable(row['selected'] == true ? row['balance'] ?? '' : '')),
        if (_showRate) DataCell(WidgetsTextSelectable(row['selected'] == true ? rateableAmount ?? "" : '')),
        if (_showRate || _showAmount)
          DataCell(
            WidgetsTextSelectable(
              row['selected'] == true && _targetSymbol.isNotEmpty && row['amount'] != null
                  ? '${Utils.formatSmartDecimal(row['amount'] ?? Decimal.zero, smartDecimal: false)} $_targetSymbol'
                  : '',
            ),
          ),
      ],
    );
  }

  Widget tableBuild() {
    final checkboxTheme = Theme.of(context).checkboxTheme;

    return SizedBox(
      width: double.infinity,
      height: tableCalculateAdjustedMaxHeight(),
      child: WidgetsTableVirtualizedSingle<Map<String, dynamic>>(
        controller: tableScrollController,
        data: tableData,
        rowBuilder: tableBuildRow,
        columnCount: tableColumns.length,
        childBuilder: (rows) => DataTable2(
          scrollController: tableScrollController,
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
          empty: Center(
            child: Text("No transactions available", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          onSelectAll: selectableOnSelectAll(() => tableData.map((r) => r['uuid'] as String)),
          columns: tableColumns,
          rows: rows,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isExiting) {
      return const SizedBox.shrink();
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 1200),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  if (txs.isNotEmpty)
                    Row(
                      spacing: 6,
                      children: [
                        const Text("Trading Transactions", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                        const Spacer(),
                        WidgetsButtonsAction(
                          icon: Icons.account_balance_wallet_outlined,
                          iconSize: 14,
                          padding: const EdgeInsets.all(10),
                          minimumSize: const Size(40, 40),
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
                          padding: const EdgeInsets.all(10),
                          minimumSize: const Size(40, 40),
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
                  if (txs.isNotEmpty) Column(spacing: 4, children: [tableBuild(), _buildTotal()]),
                  if (txs.isEmpty)
                    const Center(
                      child: Text("No transactions to trade", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                    ),
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
                        WidgetsButtonsAction(
                          label: txs.isNotEmpty ? 'Cancel' : 'Close',
                          onPressed: (_) {
                            setState(() => _isExiting = true);
                            widget.onSave?.call(null);
                          },
                          evaluator: (s) {
                            _isProcessing ? s.disable() : s.normal();
                          },
                        ),
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
          if (_isProcessing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotal() {
    final Decimal rate = rateableAmount == null ? Decimal.zero : rateableParseToDecimal(rateableAmount!, reverse: _isReversed);

    final String targetSymbol = rateableTarget != null ? _cryptoController.getSymbol(rateableTarget!) ?? "" : "";

    final bool showRate = !_useBalanceMode && rate > Decimal.zero && targetSymbol.isNotEmpty;
    final bool showAmount = _useBalanceMode && targetSymbol.isNotEmpty && _toAmount > Decimal.zero && _fromAmount > Decimal.zero;

    final Decimal source = showAmount && _fromAmount > Decimal.zero ? _fromAmount : _sourceAmount;
    final Decimal resultValue = _useBalanceMode ? _toAmount : Math.multiply(source, rate);

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
                  height: hasError ? 110 : 92,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: WidgetsHeader(spacing: 10, children: [_buildFromTitleField(), _buildFromAmountField()])),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 40),
                        child: Icon(_useBalanceMode ? Icons.arrow_forward : Icons.clear, size: 24),
                      ),
                      Expanded(
                        child: WidgetsHeader(
                          subtitle: "To:",
                          subtitleFontSize: 13,
                          spacing: 10,
                          child: _useBalanceMode ? _buildToAmountField() : _buildRatesAmountField(),
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
                    Expanded(child: WidgetsHeader(spacing: 10, children: [_buildFromTitleField(), _buildFromAmountField()])),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: WidgetsHeader(
                        subtitle: "To:",
                        subtitleFontSize: 13,
                        spacing: 10,
                        child: _useBalanceMode ? _buildToAmountField() : _buildRatesAmountField(),
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

  Widget _buildFromTitleField() {
    final bool canTakeProfit = _useBalanceMode && _calc.calculateBalanceProfit(_getSelectedTransactions()) != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("From:", style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        Spacer(),
        if (canTakeProfit) ...[
          SizedBox(
            height: 20,
            child: Checkbox(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: _takeProfit,
              onChanged: (bool? state) {
                if (!_isProcessing) {
                  if (state != null) {
                    _updateProfit(enabled: state);
                  }
                  _updateTableState();
                  setState(() {});
                }
              },
            ),
          ),
          Text("Take profit"),
        ],
      ],
    );
  }

  Widget _buildFromAmountField() {
    return _useBalanceMode
        ? WidgetsFieldsAmount(
            title: 'Amount',
            helperText: 'e.g., 10.5',
            enabled: !_isProcessing,
            suffixText: _selectedSymbol,
            useMax: _sourceAmount,
            controller: fromController,
            disposeController: false,
            onChanged: (value) {
              setState(() {
                _fromAmount = Utils.parseDecimal(value);
                _updateTableState();
              });
            },
          )
        : TextField(
            contextMenuBuilder: (context, editableTextState) {
              return WidgetsContextMenu(
                anchor: editableTextState.contextMenuAnchors.primaryAnchor,
                buttonItems: editableTextState.contextMenuButtonItems,
              );
            },
            controller: TextEditingController(
              text: selectableHasSelectedRows() ? "$_sourceAmount $_selectedSymbol" : "No transaction selected",
            ),
            readOnly: true,
            style: TextStyle(fontSize: 16),
          );
  }

  Widget _buildToAmountField() {
    return WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'e.g., 10.5',
      enabled: !_isProcessing,
      controller: toController,
      disposeController: false,
      onChanged: (value) {
        setState(() {
          _toAmount = Utils.parseDecimal(value);
          _updateTableState();
        });
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
              _updateTableState();
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
        _updateTableState();
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
        enabled: !_isProcessing,
        onChanged: (value) {
          _updateRate(value);
          _updateTableState();
          setState(() {});
        },
      ),
    );
  }

  void _updateTableState() {
    final Decimal rate = rateableAmount == null ? Decimal.zero : rateableParseToDecimal(rateableAmount!, reverse: _isReversed);

    _targetSymbol = rateableTarget != null ? _cryptoController.getSymbol(rateableTarget!) ?? "" : "";
    _showRate = !_useBalanceMode && rate > Decimal.zero && _targetSymbol.isNotEmpty;
    _showAmount = _useBalanceMode && _targetSymbol.isNotEmpty && _toAmount > Decimal.zero && _fromAmount > Decimal.zero;

    tableBuildColumns();
    tablePopulateData();
  }

  void _updateProfit({bool? enabled}) {
    final shouldTakeProfit = enabled ?? _takeProfit;
    final profit = shouldTakeProfit ? _calc.calculateBalanceProfit(_getSelectedTransactions()) : null;

    _takeProfit = shouldTakeProfit && profit != null;
    if (profit == null) return;

    final formattedProfit = Utils.formatSmartDecimal(profit, smartDecimal: false, maxDecimals: 18).replaceAll(',', '');
    fromController.text = formattedProfit;
    _fromAmount = Utils.parseDecimal(formattedProfit);
  }

  Map<String, Decimal> _spreadByWeights(Decimal amount, List<TransactionsModel> transactions, Map<String, Decimal> weights) {
    final totalWeight = weights.values.fold<Decimal>(Decimal.zero, Math.add);
    if (totalWeight <= Decimal.zero) {
      return {for (final tx in transactions) tx.uuid: Decimal.zero};
    }

    final lastPositive = transactions.lastIndexWhere((tx) => (weights[tx.uuid] ?? Decimal.zero) > Decimal.zero);
    final allocations = <String, Decimal>{};
    var allocated = Decimal.zero;
    final unitAmount = Math.divide(amount, totalWeight);

    for (var index = 0; index < transactions.length; index++) {
      final tx = transactions[index];
      final weight = weights[tx.uuid] ?? Decimal.zero;
      if (weight <= Decimal.zero) {
        allocations[tx.uuid] = Decimal.zero;
        continue;
      }

      final allocation = index == lastPositive ? Math.subtract(amount, allocated) : Math.multiply(unitAmount, weight);
      allocations[tx.uuid] = allocation;
      allocated = Math.add(allocated, allocation);
    }

    return allocations;
  }

  List<TransactionsModel> _getSelectedTransactions() {
    final stxs = [...txs];

    final selectedTxIds = selectableGetSelectedRows();
    stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid) && (tx.isActive || tx.isPartial));

    return stxs;
  }

  void _updateRate(String totalAmount) {
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
    final Decimal entryRate = rateableParseToDecimal(rateText ?? "", reverse: _isReversed);
    final Decimal resultValue = Math.multiply(_sourceAmount, entryRate);

    resultController.text = resultValue <= Decimal.zero ? "" : Utils.formatSmartDecimal(resultValue, smartDecimal: false, maxDecimals: 18);
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final stxs = _getSelectedTransactions();

    if (stxs.isEmpty) return;

    Decimal rate = Decimal.zero;
    Decimal profitPool = Decimal.zero;
    Map<String, Decimal> fromAllocations = {};
    Map<String, Decimal> toAllocations = {};

    if (_takeProfit) {
      if (_toAmount <= Decimal.zero ||
          _fromAmount <= Decimal.zero ||
          _fromAmount > Utils.sanitizeFractalDecimal(_calc.calculateBalanceProfit(stxs) ?? Decimal.zero)) {
        return;
      }

      profitPool = _fromAmount;
    } else if (_useBalanceMode) {
      if (_fromAmount <= Decimal.zero || _toAmount <= Decimal.zero || _fromAmount > _calc.totalActiveBalance(stxs)) {
        return;
      }

      fromAllocations = _calc.spreadAmount(_fromAmount, stxs);
      toAllocations = _calc.spreadAmount(_toAmount, stxs);
    } else {
      rate = rateableAmount == null ? Decimal.zero : rateableParseToDecimal(rateableAmount!, reverse: _isReversed);
      if (rate <= Decimal.zero) return;
    }

    setState(() {
      _isProcessing = true;
    });

    bool completed = true;

    List<TransactionsModel> payload = [];
    Map<String, TransactionsModel> map = {};

    for (final tx in stxs) {
      Decimal sourceAmount;
      Decimal amount;
      Decimal tempPoolValue = Decimal.zero;

      if (_takeProfit) {
        if (profitPool <= Decimal.zero) break;

        final txProfit = Math.subtract(tx.balance, tx.rrAmount);

        if (txProfit <= Decimal.zero) continue;

        sourceAmount = txProfit < profitPool ? txProfit : profitPool;
        amount = Math.divide(Math.multiply(_toAmount, sourceAmount), _fromAmount);

        tempPoolValue = Utils.sanitizeFractalDecimal(Math.subtract(profitPool, sourceAmount));
      } else if (_useBalanceMode) {
        sourceAmount = fromAllocations[tx.uuid] ?? Decimal.zero;
        amount = toAllocations[tx.uuid] ?? Decimal.zero;
      } else {
        sourceAmount = tx.balance;
        amount = Math.multiply(tx.balance, rate);
      }

      final meta = Map<String, dynamic>.from(tx.meta);

      if (_noteEntry != null) {
        meta['trading_notes'] = _noteEntry;
      }

      if (_accentColor != null) {
        meta['accent_color'] = _accentColor!.toARGB32().toRadixString(16).padLeft(8, '0');
      }

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

      payload.add(child);
      map[child.uuid] = tx;

      if (_takeProfit) {
        profitPool = tempPoolValue;
      }
    }

    final success = await _txController.addAll(payload);
    for (final uuid in success) {
      final parent = map[uuid];
      if (parent != null) {
        txs.remove(parent);
        selectableSetSelected(parent.uuid, false);
      }
    }

    if (success.length < payload.length) {
      completed = false;
      final totalCount = payload.length;
      final successCount = success.length;
      final failedCount = totalCount - successCount;

      final devMessage = 'Batch trades partially or fully failed: $failedCount of $totalCount failed ($successCount succeeded).';

      final uxMessage = successCount == 0
          ? 'Unable to trade the selected transactions. Please check their status and try again.'
          : '$failedCount of $totalCount transactions could not be traded. Remaining items are still selected.';

      widget.onSave?.call(BatchException(AppErrorCode.batchOpsFailed, devMessage, uxMessage));
    }

    tablePopulateData();

    if (completed) {
      if (txs.isEmpty) {
        widget.onSave?.call(null);
        setState(() {
          _isExiting = true;
        });
      } else {
        widgetsNotifySuccess("Trade completed successfully.");
      }
    }

    if (txs.isNotEmpty) {
      _formKey.currentState?.reset();

      setState(() {
        _isProcessing = false;
        _sourceAmount = Utils.sanitizeFractalDecimal(_calc.totalActiveBalance(_getSelectedTransactions()));

        if (_sourceAmount <= Decimal.zero) {
          _takeProfit = false;
        }

        if (_useBalanceMode && !_takeProfit) {
          fromController.text = Utils.formatSmartDecimal(_sourceAmount, smartDecimal: false, maxDecimals: 18);
        }
      });
    }
  }
}
