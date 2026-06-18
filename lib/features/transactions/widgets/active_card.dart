import 'dart:async';
import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../core/math.dart';
import '../../../core/utils.dart';
import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../mixins/actionable.dart';
import '../../../mixins/rateable.dart';
import '../../../mixins/selectable_table.dart';
import '../../../mixins/sortable_table.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/button.dart';
import '../../../widgets/dialogs/show_form.dart';
import '../../../widgets/fields/amount.dart';
import '../../../widgets/header.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../../watchboard/panels/controller.dart';
import '../../watchboard/panels/form.dart';
import '../../watchboard/panels/model.dart';
import '../../watchers/controller.dart';
import '../../watchers/form.dart';
import '../../watchers/model.dart';
import '../dialogs/batch_action.dart';
import '../dialogs/batch_trade.dart';
import '../mixins/actions.dart';
import '../widgets/buttons.dart';
import '../calculations.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsActiveCard extends StatefulWidget {
  final int srid;
  final int rrid;

  final List<TransactionsModel> transactions;
  final VoidCallback onStatusChanged;

  final BuildContext parentContext;

  final bool isOpen;

  const TransactionsActiveCard({
    super.key,
    required this.parentContext,
    required this.srid,
    required this.rrid,
    required this.transactions,
    required this.onStatusChanged,
    required this.isOpen,
  });

  @override
  State<TransactionsActiveCard> createState() => _TransactionsActiveCardState();
}

class _TransactionsActiveCardState extends State<TransactionsActiveCard>
    with
        AutomaticKeepAliveClientMixin,
        MixinsActionable,
        MixinsState,
        MixinsTable,
        MixinsSelectableTable,
        MixinsSortableTable<TransactionsActiveCard>,
        MixinsRateable<TransactionsActiveCard>,
        TransactionsMixinsActions {
  final _calc = TransactionCalculation();

  late final CryptosController _cryptosController;
  late final WatchersController _wxController;
  late final PanelsController _pxController;

  late String _sourceSymbol;
  late String _resultSymbol;

  double _currentRate = 0;
  double _averageRate = 0;
  double _totalSourceBalance = 0;
  double _totalBalance = 0;
  double _totalPL = 0;
  double _totalProfit = 0;
  double _totalLoss = 0;
  double _plPercentage = 0;

  bool _isReversed = false;

  bool _isOpen = true;

  double? _customRate;

  Timer? _debounce;

  double? get effectiveMarketRate {
    final m = rateableValue;
    if (m == null) return null;

    return _isReversed ? (m == 0 ? null : Math.divide(1, m)) : m;
  }

  double? get nonReversedEffectiveRate {
    final c = _customRate;
    if (c != null) {
      return _isReversed ? Math.divide(1, c) : c;
    }

    final m = rateableValue;
    if (m != null) {
      return m;
    }

    return _calc.averageExchangedRate(txs, reverse: false);
  }

  bool get isCapital => (widget.srid == widget.rrid);

  @override
  String get sortableKey => "tx-group-active-${widget.srid}-${widget.rrid}";

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    rateableIsTemporary = false;
    rateableSource = widget.srid;
    rateableTarget = widget.rrid;

    _isOpen = widget.isOpen;

    txs = widget.transactions;
    txController = locator<TransactionsController>();

    _cryptosController = locator<CryptosController>();
    _sourceSymbol = _cryptosController.getSymbol(widget.srid) ?? 'Unknown Coin';
    _resultSymbol = _cryptosController.getSymbol(widget.rrid) ?? 'Unknown Coin';

    _wxController = locator<WatchersController>();
    _wxController.start();

    _pxController = locator<PanelsController>();
    _pxController.start();

    sortableSorters = {
      0: (col, asc) => sortableOnSort((d) => d['_timestamp'] as int, col, asc),
      1: (col, asc) => sortableOnSort((d) => d['_sourceValue'] as double, col, asc),
      2: (col, asc) => sortableOnSort((d) => d['_targetValue'] as double, col, asc),
      3: (col, asc) => sortableOnSort((d) => d['_balanceValue'] as double, col, asc),
      4: (col, asc) => sortableOnSort((d) => d['_exchangedRateValue'] as double, col, asc),
      5: (col, asc) => sortableOnSort((d) => d['status'] as String, col, asc),
      6: (col, asc) => sortableOnSort((d) => d['_currentValue'] as double, col, asc),
      7: (col, asc) => sortableOnSort((d) => d['_profitLossValue'] as double, col, asc),
      8: (col, asc) => sortableOnSort((d) => d['_profitLossPercentage'] as double, col, asc),
      9: (col, asc) => sortableOnSort((d) => d['status'] as String, col, asc),
    };

    _calculateProfitLoss();

    // Rateable callback will try to build rows
    rateableGetRate(refresh: false, silent: true);
    if (rows.isEmpty && txs.isNotEmpty) {
      rows = _buildRows();
    }

    sortableApplySorting();

    checkForClosable();
    checkForDeletable();
    checkForFinalizable();
    checkForRefundable();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsActiveCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (oldWidget.isOpen != widget.isOpen) {
      setState(() {
        _isOpen = widget.isOpen;
      });
    }

    if (txController.isBothEqualGroup(oldWidget.transactions, widget.transactions)) {
      return;
    }

    setState(() {
      txs = widget.transactions;
      _calculateProfitLoss();
      rows = _buildRows();
      sortableApplySorting();

      _sourceSymbol = _cryptosController.getSymbol(widget.srid) ?? 'Unknown Coin';
      _resultSymbol = _cryptosController.getSymbol(widget.rrid) ?? 'Unknown Coin';

      checkForClosable();
      checkForDeletable();
      checkForFinalizable();
      checkForRefundable();
    });
  }

  @override
  void rateableUpdateRate() {
    rateableGetRate(silent: true);
  }

  void _calculateProfitLoss() {
    final stxs = [...txs];

    if (selectableHasSelectedRows()) {
      final selectedTxIds = selectableGetSelectedRows();
      stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));
    }

    final atxs = stxs.where((tx) => tx.isActive || tx.isPartial).toList();

    _averageRate = _calc.averageExchangedRate(stxs, reverse: _isReversed);
    _currentRate = _customRate ?? effectiveMarketRate ?? 0.0;
    _totalSourceBalance = _calc.totalSourceBalance(stxs, shrinkPartial: true);
    _totalBalance = _calc.totalBalance(stxs);
    _totalPL = _calc.totalProfitLoss(atxs, _currentRate, reverse: _isReversed, shrinkPartial: true);
    _totalProfit = _calc.totalProfit(atxs, _currentRate, reverse: _isReversed, shrinkPartial: true);
    _totalLoss = _calc.totalLoss(atxs, _currentRate, reverse: _isReversed, shrinkPartial: true);
    _plPercentage = _calc.profitLossPercentage(atxs, _currentRate, reverse: _isReversed, shrinkPartial: true);
  }

  @override
  void rateableGetCallback() {
    if (rateableStateUpdater != null) {
      _customRate = rateableValue;
    } else {
      if (_customRate != null) {
        rateableValue = _customRate;
      }
    }
    rateableDefaultHelper = _averageRate.toStringAsFixed(8);
    _calculateProfitLoss();
    rows = _buildRows();
    sortableApplySorting();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WidgetsPanel(child: Column(spacing: 20, children: [_buildHeader(), if (_isOpen) _buildTable()]));
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      key: Key("header-${widget.srid}-${widget.rrid}"),
      builder: (context, constraints) {
        if (constraints.maxWidth > 1000) {
          return Row(
            spacing: 20,
            children: [
              _buildTitle(CrossAxisAlignment.start),
              Expanded(child: _buildPanels()),
              _buildActions(),
            ],
          );
        } else {
          return Wrap(
            direction: Axis.horizontal,
            runSpacing: 14,
            spacing: 10,
            runAlignment: WrapAlignment.center,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [_buildTitle(CrossAxisAlignment.center), _buildActions(), _buildPanels()],
          );
        }
      },
    );
  }

  Widget _buildTitle(CrossAxisAlignment align) {
    return Column(
      key: Key("title-${widget.srid}-${widget.rrid}"),
      crossAxisAlignment: align,
      children: [
        const SizedBox(height: 5),
        isCapital
            ? Text('$_sourceSymbol Capital', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
            : Text('$_sourceSymbol to $_resultSymbol Trades', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),

        isCapital
            ? Text('Coin ID: ${widget.srid}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))
            : Text('Coin ID: ${widget.srid} - ${widget.rrid}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildActions() {
    final btnIconSize = 18.0;
    final btnSize = const Size(40, 40);
    final btnPadding = const EdgeInsets.all(0);

    return Wrap(
      direction: Axis.horizontal,
      runSpacing: 14,
      spacing: 8,
      runAlignment: WrapAlignment.center,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!isCapital)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              SizedBox(
                width: 180,
                height: 40,
                child: WidgetsFieldsAmount(
                  key: Key(_isReversed ? "Reversed" : "Normal"),
                  title: "Custom Rates",
                  suffixText: _isReversed ? _resultSymbol : _sourceSymbol,
                  helperText: _averageRate.toStringAsFixed(8),
                  initialValue: _customRate != null ? Utils.formatSmartDouble(_customRate!) : "",
                  allowCopy: false,
                  allowRate: true,
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

                    _debounce = Timer(const Duration(milliseconds: 100), () {
                      setState(() {
                        _customRate = double.tryParse(value);
                        rateableGetRate(silent: true);
                      });
                    });
                  },
                ),
              ),

              WidgetsButton(
                icon: Icons.swap_horiz,
                padding: btnPadding,
                iconSize: btnIconSize,
                minimumSize: btnSize,
                tooltip: _isReversed ? "Click to Inverse rate" : "Click to reverse rate",
                evaluator: (s) {
                  if (_isReversed) {
                    s.action();
                  } else {
                    s.normal();
                  }
                },
                onPressed: (_) {
                  setState(() {
                    _isReversed = !_isReversed;
                    if (_customRate != null) {
                      _customRate = Math.divide(1, _customRate!);
                    }

                    // BugFix: Dont link to rateable to prevent double inversing!
                    _currentRate = _customRate ?? effectiveMarketRate ?? 0.0;
                    _calculateProfitLoss();
                    rows = _buildRows();
                    sortableApplySorting();
                  });
                },
              ),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            if (!isCapital)
              AnimatedBuilder(
                animation: _pxController,
                builder: (context, _) {
                  final linkedPanel = _pxController.getLinked("active-screen-${widget.srid}-${widget.rrid}");
                  return WidgetsDialogsShowForm(
                    key: const Key("add-watchboard-button"),
                    icon: Icons.candlestick_chart_outlined,
                    padding: btnPadding,
                    iconSize: btnIconSize,
                    minimumSize: btnSize,
                    tooltip: linkedPanel == null ? "Add new watchboard" : "Edit watchboard",
                    persistBg: true,
                    evaluator: (s) {
                      if (linkedPanel == null) {
                        s.normal();
                      } else {
                        s.action();
                      }
                    },
                    buildForm: (dialogContext) {
                      return PanelsForm(
                        initialData: linkedPanel,
                        initialSrId: linkedPanel == null ? widget.srid : null,
                        initialRrId: linkedPanel == null ? widget.rrid : null,
                        initialSrAmount: linkedPanel == null ? _calc.totalActiveSourceBalance(txs) : null,
                        linkedToTx: "active-screen-${widget.srid}-${widget.rrid}",
                        onSave: (e) => actionableFormSave<PanelsModel>(
                          context,
                          dialogContext: dialogContext,
                          successMessage: linkedPanel == null ? "Created watchboard entry." : "Watchboard entry updated",
                          error: e,
                        ),
                      );
                    },
                  );
                },
              ),

            if (!isCapital)
              AnimatedBuilder(
                animation: _wxController,
                builder: (context, _) {
                  final linkedWatcher = _wxController.getLinked("active-screen-${widget.srid}-${widget.rrid}");
                  return WidgetsDialogsShowForm(
                    key: const Key("add-watcher-button"),
                    icon: Icons.add_alarm,
                    padding: btnPadding,
                    iconSize: btnIconSize,
                    minimumSize: btnSize,
                    tooltip: linkedWatcher == null ? "Add new watcher" : "Edit watcher",
                    persistBg: true,
                    evaluator: (s) {
                      if (linkedWatcher == null) {
                        s.normal();
                      } else {
                        linkedWatcher.isSpent ? s.error() : s.action();
                      }
                    },
                    buildForm: (dialogContext) {
                      return WatchersForm(
                        initialData: linkedWatcher,
                        initialSrId: linkedWatcher == null ? widget.srid : null,
                        initialRrId: linkedWatcher == null ? widget.rrid : null,
                        initialRate: linkedWatcher == null ? nonReversedEffectiveRate : null,
                        linkedToTx: "active-screen-${widget.srid}-${widget.rrid}",
                        onSave: (e) => actionableFormSave<WatchersModel>(
                          context,
                          dialogContext: dialogContext,
                          successMessage: linkedWatcher == null ? "Created rate watcher." : "Rate watcher updated",
                          error: e,
                        ),
                      );
                    },
                  );
                },
              ),

            if (isActive)
              WidgetsDialogsShowForm(
                key: const Key("trade-multiple-button"),
                icon: Icons.swap_vert,
                tooltip: "Show batch trade action for the selected transactions",
                padding: btnPadding,
                iconSize: btnIconSize,
                minimumSize: btnSize,
                buildForm: (dialogContext) {
                  final stxs = [...txs];

                  if (selectableHasSelectedRows()) {
                    final selectedTxIds = selectableGetSelectedRows();
                    stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));
                  }

                  return TransactionsDialogsBatchTrade(
                    srId: widget.rrid,
                    totalAmount: _totalBalance,
                    transactions: stxs,
                    onSave: (e) => actionableFormSave<TransactionsModel>(
                      widget.parentContext,
                      dialogContext: dialogContext,
                      successMessage: "Trade completed successfully.",
                      error: e,
                    ),
                  );
                },
              ),

            if (isDeletable)
              WidgetsDialogsShowForm(
                key: const Key("delete-multiple-button"),
                icon: Icons.delete,
                tooltip: "Delete all transactions",
                initialState: WidgetsButtonActionState.error,
                evaluator: (s) {
                  if (!isDeletable) {
                    s.disable();
                  } else {
                    s.error();
                  }
                },
                padding: btnPadding,
                iconSize: btnIconSize,
                minimumSize: btnSize,
                buildForm: (dialogContext) {
                  return TransactionsDialogsBatchAction(
                    transactions: txs,
                    mode: TransactionsBatchActionMode.delete,
                    onSave: (e) => actionableFormSave<TransactionsModel>(
                      widget.parentContext,
                      dialogContext: dialogContext,
                      successMessage: "All transactions deleted.",
                      error: e,
                    ),
                  );
                },
              ),

            if (isRefundable)
              WidgetsDialogsShowForm(
                key: const Key("refund-multiple-button"),
                icon: Icons.u_turn_left,
                tooltip: "Refund all refundable transactions found in this group",
                initialState: WidgetsButtonActionState.error,
                evaluator: (s) {
                  if (!isRefundable) {
                    s.disable();
                  } else {
                    s.error();
                  }
                },
                padding: btnPadding,
                iconSize: btnIconSize,
                minimumSize: btnSize,
                buildForm: (dialogContext) {
                  return TransactionsDialogsBatchAction(
                    transactions: txs,
                    mode: TransactionsBatchActionMode.refund,
                    onSave: (e) => actionableFormSave<TransactionsModel>(
                      widget.parentContext,
                      dialogContext: dialogContext,
                      successMessage: "Transactions refunded successfully.",
                      error: e,
                    ),
                  );
                },
              ),

            if (isClosable)
              WidgetsDialogsShowForm(
                key: const Key("close-multiple-button"),
                icon: Icons.close,
                tooltip: "Close all closable transactions found in this group",
                initialState: WidgetsButtonActionState.warning,
                evaluator: (s) {
                  if (!isClosable) {
                    s.disable();
                  } else {
                    s.warning();
                  }
                },
                padding: btnPadding,
                iconSize: btnIconSize,
                minimumSize: btnSize,
                buildForm: (dialogContext) {
                  return TransactionsDialogsBatchAction(
                    transactions: txs,
                    mode: TransactionsBatchActionMode.close,
                    onSave: (e) => actionableFormSave<TransactionsModel>(
                      widget.parentContext,
                      dialogContext: dialogContext,
                      successMessage: "Transactions closed successfully.",
                      error: e,
                    ),
                  );
                },
              ),

            if (isFinalizable)
              WidgetsDialogsShowForm(
                key: const Key("finalize-multiple-button"),
                icon: Icons.close_fullscreen,
                tooltip: "Finalize all finalizable transactions found in this group",
                initialState: WidgetsButtonActionState.warning,
                evaluator: (s) {
                  if (!isFinalizable) {
                    s.disable();
                  } else {
                    s.warning();
                  }
                },
                padding: btnPadding,
                iconSize: btnIconSize,
                minimumSize: btnSize,
                buildForm: (dialogContext) {
                  return TransactionsDialogsBatchAction(
                    transactions: txs,
                    mode: TransactionsBatchActionMode.finalize,
                    onSave: (e) => actionableFormSave<TransactionsModel>(
                      widget.parentContext,
                      dialogContext: dialogContext,
                      successMessage: "All transactions finalized.",
                      error: e,
                    ),
                  );
                },
              ),

            WidgetsButton(
              key: const Key("toggle-show-button"),
              icon: _isOpen ? Icons.expand_less : Icons.expand_more,
              padding: btnPadding,
              iconSize: btnIconSize,
              minimumSize: btnSize,
              tooltip: _isOpen ? "Hide table" : "Show table",
              onPressed: (_) {
                setState(() {
                  _isOpen = !_isOpen;
                  states.set("tx-group-active-open-$rateableSource-$rateableTarget", _isOpen);
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTable() {
    final canSelect = !isCapital && rows.length > 1;

    return SizedBox(
      width: double.infinity,
      height: tableCalculateHeight(),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
        child: DataTable2(
          key: Key("table-${widget.srid}-${widget.rrid}"),
          headingCheckboxTheme: Theme.of(context).checkboxTheme,
          datarowCheckboxTheme: Theme.of(context).checkboxTheme,
          showHeadingCheckBox: canSelect,
          showCheckboxColumn: canSelect,
          minWidth: 1200,
          columnSpacing: 12,
          horizontalMargin: 12,
          headingRowHeight: tableHeadingHeight,
          dataRowHeight: tableRowHeight,
          sortColumnIndex: (_currentRate == 0.0 && sortableColumnIndex > 4) ? null : sortableColumnIndex,
          sortAscending: sortableAscending,
          isHorizontalScrollBarVisible: false,
          columns: [
            DataColumn2(label: const Text('Date'), fixedWidth: 100, onSort: sortableSorters[0]),
            DataColumn2(
              size: ColumnSize.S,
              label: WidgetsHeader(title: (!isCapital) ? 'From ' : 'Amount', subtitle: _sourceSymbol),
              onSort: sortableSorters[1],
            ),
            if (!isCapital)
              DataColumn2(
                size: ColumnSize.S,
                label: WidgetsHeader(title: 'To ', subtitle: _resultSymbol),
                onSort: sortableSorters[2],
              ),
            if (!isCapital)
              DataColumn2(
                size: ColumnSize.S,
                label: WidgetsHeader(title: 'Balance ', subtitle: _resultSymbol),
                onSort: sortableSorters[3],
              ),
            if (!isCapital)
              DataColumn2(
                size: ColumnSize.S,
                label: WidgetsHeader(
                  title: 'Exchanged Rate ',
                  subtitle: _isReversed ? '$_sourceSymbol / $_resultSymbol' : '$_resultSymbol / $_sourceSymbol',
                ),
                onSort: sortableSorters[4],
              ),

            if (_currentRate != 0.0 && !isCapital) ...[
              DataColumn2(
                size: ColumnSize.S,
                label: WidgetsHeader(
                  title: 'Current Rate ',
                  subtitle: _isReversed ? '$_sourceSymbol / $_resultSymbol' : '$_resultSymbol / $_sourceSymbol',
                ),
              ),
              DataColumn2(
                size: ColumnSize.S,
                label: WidgetsHeader(title: 'Current Value ', subtitle: _sourceSymbol),
                onSort: sortableSorters[6],
              ),
              DataColumn2(
                size: ColumnSize.S,
                label: WidgetsHeader(title: 'Profit/Loss ', subtitle: _sourceSymbol),
                onSort: sortableSorters[7],
              ),
              DataColumn2(
                fixedWidth: 100,
                label: const WidgetsHeader(title: 'P/L', subtitle: "%"),
                onSort: sortableSorters[8],
              ),
            ],

            DataColumn2(
              label: const Text('Status '),
              fixedWidth: 100,
              onSort: (_currentRate == 0.0) ? sortableSorters[5] : sortableSorters[9],
            ),
            const DataColumn2(label: Text('Actions'), fixedWidth: 160),
          ],

          rows: rows.map((r) {
            final tx = r['tx'] as TransactionsModel;
            final canSelect = tx.isActive || tx.isPartial;
            return DataRow(
              key: ValueKey(r['uuid']),
              selected: canSelect ? selectableIsSelected(r['uuid']) : false,
              onSelectChanged: canSelect
                  ? (v) {
                      setState(() {
                        selectableSetSelected(r['uuid'], v!);
                        _calculateProfitLoss();
                        sortableApplySorting();
                      });
                    }
                  : null,
              cells: [
                DataCell(Text(r['date'] ?? '0.0')),
                DataCell(Text(r['from'] ?? '0.0')),
                if (!isCapital) DataCell(Text(r['to'] ?? '0.0')),
                if (!isCapital) DataCell(Text(r['balance'] ?? '0.0')),
                if (!isCapital) DataCell(Text(r['exchangedRate'] ?? '0.0')),

                if (_currentRate != 0 && !isCapital) ...[
                  DataCell(WidgetsBalanceText(text: r['currentRate'] ?? "-", value: r['profitLevel'], comparator: 0, hidePrefix: true)),
                  DataCell(WidgetsBalanceText(text: r['currentValue'] ?? "-", value: r['profitLevel'], comparator: 0, hidePrefix: true)),
                  DataCell(WidgetsBalanceText(text: r['profitLoss'] ?? "-", value: r['profitLevel'], comparator: 0)),
                  DataCell(WidgetsBalanceText(text: r['profitLossPercentage'] ?? "-", value: r['profitLevel'], comparator: 0)),
                ],

                DataCell(Text(r['status'])),
                DataCell(
                  TransactionsWidgetsButtons(
                    key: Key("action-${tx.uuid}"),
                    tx: r['tx'],
                    cryptosController: _cryptosController,
                    txController: txController,
                    onAction: () {
                      widget.onStatusChanged();
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildRows() {
    final currentRate = _customRate ?? effectiveMarketRate ?? 0.0;
    final rx = <Map<String, dynamic>>[];

    for (final tx in txs) {
      double rowRate = currentRate;
      double currentValue = 0;
      double profitLoss = 0;
      double profitLevel = 0;
      double profitLossPercentage = 0;
      double currentSrAmount = tx.srAmount;

      if (tx.isFinalized) {
        profitLoss = 0;
        profitLevel = 0;
        rowRate = tx.rateDouble;
        currentValue = tx.balance;
      } else if (currentRate != 0 && tx.balance != 0 && !tx.isClosed) {
        if (tx.isPartial) {
          currentSrAmount = Math.multiply(Math.divide(tx.balance, tx.rrAmount), tx.srAmount);
        }

        currentValue = _isReversed ? Math.multiply(tx.balance, currentRate) : Math.divide(tx.balance, currentRate);
        profitLoss = Math.subtract(currentValue, currentSrAmount);
        profitLossPercentage = Math.multiply(Math.divide(profitLoss, currentSrAmount), 100);

        if (profitLoss > 0) {
          profitLevel = 1;
        } else if (profitLoss < 0) {
          profitLevel = -1;
        }
      }

      rx.add({
        'from': tx.srAmountText,
        'to': tx.rrAmountText,
        'balance': tx.balanceText,
        'exchangedRate': _isReversed ? tx.rateReversedText : tx.rateText,
        'currentRate': currentRate == 0 ? null : Utils.formatSmartDouble(rowRate),
        'currentValue': currentRate == 0 ? null : Utils.formatSmartDouble(currentValue),
        'profitLoss': currentRate == 0 ? null : Utils.formatSmartDouble(profitLoss),
        'profitLossPercentage': currentRate == 0 ? null : Utils.formatSmartDouble(profitLossPercentage, maxDecimals: 2),
        'profitLevel': profitLevel,
        'status': tx.statusText,
        'date': tx.timestampAsFormattedDate,
        'tx': tx,
        'uuid': tx.uuid,

        '_timestamp': tx.sanitizedTimestamp,
        '_targetValue': tx.rrAmount,
        '_sourceValue': tx.srAmount,
        '_balanceValue': tx.balance,
        '_exchangedRateValue': tx.rateDouble,
        '_currentValue': currentValue,
        '_profitLossValue': profitLoss,
        '_profitLossPercentage': profitLossPercentage,
      });
    }

    return rx;
  }

  Widget _buildPanels() {
    return SizedBox(
      height: 38,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
        child: CustomScrollView(
          scrollDirection: Axis.horizontal,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Row(
                key: Key("panels-${widget.srid}-${widget.rrid}"),
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                spacing: 16,
                children: [
                  _buildPanelItem(
                    title: 'Total Balance',
                    subtitle: isCapital
                        ? '${Utils.formatSmartDouble(_totalBalance)} $_sourceSymbol'
                        : '${Utils.formatSmartDouble(_totalSourceBalance)} $_sourceSymbol - ${Utils.formatSmartDouble(_totalBalance)} $_resultSymbol',
                    value: 0,
                    comparator: 0,
                  ),

                  if (!isCapital)
                    _buildPanelItem(title: 'Avg Rate', subtitle: Utils.formatSmartDouble(_averageRate), value: 0, comparator: 0),

                  if (_plPercentage != 0 && _plPercentage.isFinite && !isCapital) ...[
                    if (_totalProfit != 0.0 && _totalLoss != 0.0)
                      _buildPanelItem(title: 'Profit', subtitle: Utils.formatSmartDouble(_totalProfit), value: _totalProfit, comparator: 0),

                    if (_totalProfit != 0.0 && _totalLoss != 0.0)
                      _buildPanelItem(title: 'Loss', subtitle: Utils.formatSmartDouble(_totalLoss), value: _totalLoss, comparator: 0),

                    _buildPanelItem(
                      title: 'Total P/L',
                      subtitle: "${Utils.formatSmartDouble(_totalPL)} $_sourceSymbol",
                      value: _plPercentage,
                      comparator: 0,
                    ),

                    _buildPanelItem(
                      title: 'P/L %',
                      subtitle: '${Utils.formatSmartDouble(_plPercentage, maxDecimals: 2)}%',
                      value: _plPercentage,
                      comparator: 0,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelItem({required String title, required String subtitle, required double value, required double comparator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        const SizedBox(height: 1),
        WidgetsBalanceText(text: subtitle, value: value, comparator: comparator, fontSize: 13),
      ],
    );
  }
}
