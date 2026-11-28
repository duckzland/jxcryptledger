import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../app/exceptions.dart';
import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/log.dart';
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
import '../../../widgets/with_tooltip.dart';
import '../../cryptos/controller.dart';
import '../batch/ops.dart';
import '../calculations.dart';
import '../controller.dart';
import '../helper.dart';
import '../model.dart';

enum TransactionsDialogBatchTradeMode { rate, profit, balance }

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
  late Decimal _maxAmount;
  late List<TransactionsModel> txs;

  late TextEditingController rateController;
  late TextEditingController resultController;
  late TextEditingController fromController;
  late TextEditingController toController;

  Decimal _fromAmount = Decimal.zero;
  Decimal _toAmount = Decimal.zero;

  Color? _accentColor;
  String _targetSymbol = "";
  String? _noteEntry;

  bool _isReversed = false;
  bool _showNotes = false;
  bool _showRate = false;
  bool _showAmount = false;

  bool _isProcessing = false;
  bool _isExiting = false;

  Timer? _debounce;

  TransactionsDialogBatchTradeMode _mode = TransactionsDialogBatchTradeMode.rate;

  final Map<String, Decimal> _compoundedProfits = {};

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
    _maxAmount = _sourceAmount;

    for (final tx in txs) {
      selectableSetSelected(tx.uuid, true);
    }

    _updateCompoundedProfits();
    _updateTableState();
    _updateField();
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
  void didUpdateWidget(covariant TransactionsDialogsBatchTrade oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_txController.isBothEqualGroup(oldWidget.transactions ?? [], widget.transactions ?? [])) {
      return;
    }

    txs = List.from(widget.transactions ?? []);
    txs.retainWhere((tx) => tx.isActive || tx.isPartial);

    _updateCompoundedProfits();
    _updateTableState();
    _updateField();
  }

  @override
  void rateableGetCallback(bool hasNewRate) {
    _updateResult(rateableAmount);
    _updateTableState();
  }

  List<Map<String, dynamic>> tablePopulateData() {
    tableData = <Map<String, dynamic>>[];
    final stxs = txs;
    final selectedTxs = _getSelectedTransactions();
    final allocations = _resolveAllocations(selectedTxs);

    if (_mode == TransactionsDialogBatchTradeMode.profit) {
      stxs.retainWhere((tx) => _compoundedProfits[tx.uuid] != null);
    }

    for (final tx in stxs) {
      final sourceSymbol = _cryptoController.getSymbol(tx.srId) ?? 'Unknown Coin';
      final resultSymbol = _cryptoController.getSymbol(tx.rrId) ?? 'Unknown Coin';
      final bool selected = selectableIsSelected(tx.uuid) && (tx.isActive || tx.isPartial);

      final fromAmount = allocations.from[tx.uuid] ?? Decimal.zero;
      final amount = allocations.to[tx.uuid] ?? Decimal.zero;

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
                _updateField();
                _updateResult(rateableAmount);
              });
            }
          : null,
      cells: [
        DataCell(WidgetsWithTooltip(WidgetsTextSelectable(row['date'] ?? ''), tx.noteText, tx.meta['accent_color'])),
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
          onSelectAll: (bool? selected) {
            selectableOnSelectAll(() => tableData.map((r) => r['uuid'] as String))(selected);
            setState(() {
              _updateField();
            });
          },
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
                          tooltip: _mode == TransactionsDialogBatchTradeMode.balance ? "Show rate mode" : "Show custom balance",
                          onPressed: (s) {
                            setState(() {
                              _mode = _mode == TransactionsDialogBatchTradeMode.balance
                                  ? TransactionsDialogBatchTradeMode.rate
                                  : TransactionsDialogBatchTradeMode.balance;
                              _updateField();
                            });

                            switch (_mode) {
                              case TransactionsDialogBatchTradeMode.profit:
                                s.primary();
                                break;
                              case TransactionsDialogBatchTradeMode.balance:
                                s.action();
                                break;
                              case TransactionsDialogBatchTradeMode.rate:
                                s.normal();
                                break;
                            }
                          },
                          evaluator: (s) {
                            if (_isProcessing) {
                              s.disable();
                              return;
                            }

                            switch (_mode) {
                              case TransactionsDialogBatchTradeMode.profit:
                                s.primary();
                                break;
                              case TransactionsDialogBatchTradeMode.balance:
                                s.action();
                                break;
                              case TransactionsDialogBatchTradeMode.rate:
                                s.normal();
                                break;
                            }
                          },
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
                          onPressed: (_) => Navigator.pop(context),
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

    final bool isRateMode = _mode == TransactionsDialogBatchTradeMode.rate;
    final bool showRate = isRateMode && rate > Decimal.zero && targetSymbol.isNotEmpty;
    final bool showAmount = !isRateMode && targetSymbol.isNotEmpty && _toAmount > Decimal.zero && _fromAmount > Decimal.zero;

    final Decimal source = showAmount && _fromAmount > Decimal.zero ? _fromAmount : _sourceAmount;
    final Decimal resultValue = !isRateMode ? _toAmount : Math.multiply(source, rate);

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

    final isRateMode = _mode == TransactionsDialogBatchTradeMode.rate;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteractionIfError,
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
                        child: Icon(isRateMode ? Icons.clear : Icons.arrow_forward, size: 24),
                      ),
                      Expanded(
                        child: WidgetsHeader(
                          subtitle: "To:",
                          subtitleFontSize: 13,
                          spacing: 10,
                          child: isRateMode ? _buildRatesAmountField() : _buildToAmountField(),
                        ),
                      ),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 5, vertical: 40)),
                      Expanded(
                        child: WidgetsHeader(subtitle: " ", subtitleFontSize: 13, spacing: 10, child: _buildCoinSelectField()),
                      ),
                      if (isRateMode) ...[
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
                        child: isRateMode ? _buildToAmountField() : _buildRatesAmountField(),
                      ),
                    ),
                  ],
                ),
                Row(children: [Expanded(child: _buildCoinSelectField())]),
                if (!isRateMode) Row(children: [Expanded(child: _buildResultAmountField())]),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("From:", style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        Spacer(),
        if (_compoundedProfits.isNotEmpty && _mode != TransactionsDialogBatchTradeMode.rate) ...[
          SizedBox(
            height: 20,
            child: Checkbox(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: _mode == TransactionsDialogBatchTradeMode.profit,
              onChanged: (bool? state) {
                if (!_isProcessing && state != null) {
                  setState(() {
                    _mode = state ? TransactionsDialogBatchTradeMode.profit : TransactionsDialogBatchTradeMode.balance;
                    _updateField();
                    _updateTableState();
                  });
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
    final stxs = _getSelectedTransactions();
    final text = TextField(
      contextMenuBuilder: (context, editableTextState) {
        return WidgetsContextMenu(
          anchor: editableTextState.contextMenuAnchors.primaryAnchor,
          buttonItems: editableTextState.contextMenuButtonItems,
        );
      },
      controller: TextEditingController(text: selectableHasSelectedRows() ? "$_sourceAmount $_selectedSymbol" : "No transaction selected"),
      readOnly: true,
      style: TextStyle(fontSize: 16),
    );

    final input = WidgetsFieldsAmount(
      title: 'Amount',
      helperText: 'e.g., 10.5',
      enabled: !_isProcessing,
      suffixText: _selectedSymbol,
      useMax: _maxAmount,
      controller: fromController,
      disposeController: false,
      onChanged: (value) {
        setState(() {
          _fromAmount = Utils.parseDecimal(value);
          _updateTableState();
        });
      },
    );

    switch (_mode) {
      case TransactionsDialogBatchTradeMode.rate:
        return text;

      case TransactionsDialogBatchTradeMode.profit:
      case TransactionsDialogBatchTradeMode.balance:
        return stxs.isEmpty ? text : input;
    }
  }

  Widget _buildToAmountField() {
    return WidgetsFieldsAmount(
      key: Key("amount-field"),
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
      key: Key("rate_field"),
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
    _showRate = _mode == TransactionsDialogBatchTradeMode.rate && rate > Decimal.zero && _targetSymbol.isNotEmpty;
    _showAmount =
        _mode != TransactionsDialogBatchTradeMode.rate &&
        _targetSymbol.isNotEmpty &&
        _toAmount > Decimal.zero &&
        _fromAmount > Decimal.zero;

    tableBuildColumns();
    tablePopulateData();
  }

  void _updateField() {
    final stxs = _getSelectedTransactions();

    switch (_mode) {
      case TransactionsDialogBatchTradeMode.rate:
        _maxAmount = Utils.sanitizeFractalDecimal(_calc.totalActiveBalance(stxs));
        _sourceAmount = _maxAmount;
        break;
      case TransactionsDialogBatchTradeMode.profit:
        _maxAmount = Utils.sanitizeFractalDecimal(
          stxs.fold<Decimal>(Decimal.zero, (sum, tx) => Math.add(sum, _compoundedProfits[tx.uuid] ?? Decimal.zero)),
        );
        break;
      case TransactionsDialogBatchTradeMode.balance:
        _maxAmount = Utils.sanitizeFractalDecimal(_calc.totalActiveBalance(stxs));
        break;
    }
  }

  void _updateCompoundedProfits() {
    _compoundedProfits.clear();
    if (txs.isEmpty) return;

    final allTxsMap = _txController.getIndexedMap();

    for (final tx in txs) {
      final profit = _calc.totalCompoundedProfitLoss(tx, txsMap: allTxsMap);
      if (profit > Decimal.zero) {
        _compoundedProfits[tx.uuid] = profit;
      }
    }
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
    if (stxs.isEmpty) {
      logln("Refused to process no selected txs");
      return;
    }

    if (!_validate(stxs)) {
      logln("Refused to process invalid data");
      return;
    }

    if (rateableTarget == null) {
      logln("Refused to process invalid data: no valid coin id");
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final allocations = _resolveAllocations(stxs);
    final isTakeProfit = _mode == TransactionsDialogBatchTradeMode.profit;
    final accentColor = _accentColor?.toARGB32().toRadixString(16).padLeft(8, '0') ?? "";

    final ops = TransactionsBatchOps();

    for (final tx in stxs) {
      final sourceAmount = Utils.sanitizeFractalDecimal(allocations.from[tx.uuid] ?? Decimal.zero);
      final amount = Utils.sanitizeFractalDecimal(allocations.to[tx.uuid] ?? Decimal.zero);
      if (sourceAmount <= Decimal.zero || amount <= Decimal.zero) continue;

      final parent = isTakeProfit
          ? TransactionsHelper.getCloseTargetParent(tx, txsMap: _txController.getIndexedRootMap()[tx.rid] ?? _txController.getIndexedMap())
          : tx;

      if (parent == null) {
        continue;
      }

      final meta = Map<String, dynamic>.from(tx.meta);
      if (_noteEntry != null) meta['trading_notes'] = _noteEntry;
      if (accentColor.isNotEmpty) meta['accent_color'] = accentColor;

      final child = TransactionsModel(
        tid: _txController.generateId(),
        rid: parent.isRoot ? parent.tid : parent.rid,
        pid: parent.tid,
        srId: parent.rrId,
        srAmount: sourceAmount,
        rrId: rateableTarget!,
        rrAmount: amount,
        balance: amount,
        status: TransactionStatus.active.index,
        timestamp: Utils.dateToTimestamp(DateTime.now()),
        closable: false,
        meta: meta,
      );

      if (isTakeProfit) {
        ops.close(tx, tag: tx);
        ops.add(child, tag: tx);
      } else {
        ops.add(child, tag: tx);
      }
    }

    await _txController.batchOperation(ops);

    for (final tx in ops.succeededTags<TransactionsModel>()) {
      txs.remove(tx);
      selectableSetSelected(tx.uuid, false);
    }

    if (ops.isAllSuccess) {
      widgetsNotifySuccess("Trade completed successfully.");
    } else {
      logln(ops.failedMessages.join('\n'));
      widget.onSave?.call(ops.toException(AppErrorCode.batchOpsFailed, "Failed to trade some of the transactions."));
    }

    _isExiting = txs.isEmpty;
    _isProcessing = false;
    tablePopulateData();

    if (txs.isEmpty) {
      widget.onSave?.call(null);
    } else {
      _updateCompoundedProfits();

      if (_compoundedProfits.isEmpty && _mode == TransactionsDialogBatchTradeMode.profit) {
        _mode = TransactionsDialogBatchTradeMode.balance;
      }

      _updateTableState();
      _updateField();

      _formKey.currentState?.reset();
    }

    setState(() {});
  }

  bool _validate(List<TransactionsModel> txs) {
    if (_mode == TransactionsDialogBatchTradeMode.profit || _mode == TransactionsDialogBatchTradeMode.balance) {
      if (_fromAmount <= Decimal.zero || _toAmount <= Decimal.zero) {
        logln("Checking for valid amount $_fromAmount $_toAmount");
        return false;
      }
    }

    switch (_mode) {
      case TransactionsDialogBatchTradeMode.profit:
        final totalProfit = txs.fold<Decimal>(Decimal.zero, (sum, tx) => Math.add(sum, _compoundedProfits[tx.uuid] ?? Decimal.zero));
        logln("Checking for valid amount $_fromAmount $totalProfit ${Utils.sanitizeFractalDecimal(totalProfit)}");
        return _fromAmount <= Utils.sanitizeFractalDecimal(totalProfit);

      case TransactionsDialogBatchTradeMode.balance:
        logln("Checking for valid amount $_fromAmount ${_calc.totalActiveBalance(txs)}");
        return _fromAmount <= Utils.sanitizeFractalDecimal(_calc.totalActiveBalance(txs));

      case TransactionsDialogBatchTradeMode.rate:
        if (rateableAmount == null) {
          return false;
        }
        final rate = rateableParseToDecimal(rateableAmount!, reverse: _isReversed);
        return rate > Decimal.zero;
    }
  }

  List<TransactionsModel> _getSelectedTransactions() {
    final stxs = [...txs];
    if (_mode == TransactionsDialogBatchTradeMode.profit) {
      stxs.retainWhere((tx) => _compoundedProfits[tx.uuid] != null);
    }

    final selectedTxIds = selectableGetSelectedRows();
    stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid) && (tx.isActive || tx.isPartial));

    return stxs;
  }

  ({Map<String, Decimal> from, Map<String, Decimal> to}) _resolveAllocations(List<TransactionsModel> selectedTxs) {
    switch (_mode) {
      case TransactionsDialogBatchTradeMode.profit:
        return (
          from: _calc.spreadByWeights(_fromAmount, selectedTxs, _compoundedProfits),
          to: _calc.spreadByWeights(_toAmount, selectedTxs, _compoundedProfits),
        );

      case TransactionsDialogBatchTradeMode.balance:
        return (from: _calc.spreadAmount(_fromAmount, selectedTxs), to: _calc.spreadAmount(_toAmount, selectedTxs));

      case TransactionsDialogBatchTradeMode.rate:
        final rate = rateableAmount == null ? Decimal.zero : rateableParseToDecimal(rateableAmount!, reverse: _isReversed);

        return (
          from: {for (final tx in selectedTxs) tx.uuid: tx.balance},
          to: {for (final tx in selectedTxs) tx.uuid: Math.multiply(tx.balance, rate)},
        );
    }
  }
}
