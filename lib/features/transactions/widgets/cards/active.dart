import 'dart:async';

import 'package:data_table_2/data_table_2.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/math.dart';
import '../../../../core/utils.dart';
import '../../../../core/locator.dart';
import '../../../../mixins/actionable.dart';
import '../../../../mixins/rateable.dart';
import '../../../../mixins/selectable_table.dart';
import '../../../../mixins/sortable_table.dart';
import '../../../../mixins/state.dart';
import '../../../../mixins/table.dart';
import '../../../../widgets/balance_text.dart';
import '../../../../widgets/buttons/action.dart';
import '../../../../widgets/fields/amount.dart';
import '../../../../widgets/header.dart';
import '../../../../widgets/panel.dart';
import '../../../../widgets/table/column.dart';
import '../../../../widgets/table/proxy.dart';
import '../../../../widgets/with_tooltip.dart';
import '../../../cryptos/controller.dart';
import '../../dialogs/details.dart';
import '../../mixins/actions.dart';
import '../../mixins/flags.dart';
import '../buttons/action.dart';
import '../../calculations.dart';
import '../../controller.dart';
import '../../model.dart';
import '../buttons/batch.dart';
import '../panel_item.dart';
import '../status_text.dart';

class TransactionsWidgetsCardsActive extends StatefulWidget {
  final int srid;
  final int rrid;

  final List<TransactionsModel> transactions;
  final Map<String, Map<TransactionsFlagsType, bool>> txsFlags;

  final VoidCallback onStatusChanged;
  final VoidCallback onToggleChanged;

  final BuildContext parentContext;

  final ThemeData theme;

  final bool isOpen;

  final ScrollController scrollController;

  const TransactionsWidgetsCardsActive({
    super.key,
    required this.parentContext,
    required this.theme,
    required this.srid,
    required this.rrid,
    required this.transactions,
    required this.onStatusChanged,
    required this.onToggleChanged,
    required this.isOpen,
    required this.txsFlags,
    required this.scrollController,
  });

  @override
  State<TransactionsWidgetsCardsActive> createState() => _TransactionsWidgetsCardsActiveState();
}

class _TransactionsWidgetsCardsActiveState extends State<TransactionsWidgetsCardsActive>
    with
        MixinsActionable,
        MixinsState,
        MixinsTable,
        MixinsSelectableTable,
        MixinsSortableTable<TransactionsWidgetsCardsActive>,
        MixinsRateable<TransactionsWidgetsCardsActive>,
        TransactionsMixinsActions,
        TransactionsMixinsFlags {
  final _calc = TransactionCalculation();

  late final CryptosController _cryptosController;

  late String _sourceSymbol;
  late String _resultSymbol;

  Decimal _currentRate = Decimal.zero;
  Decimal _averageRate = Decimal.zero;
  Decimal _totalSourceBalance = Decimal.zero;
  Decimal _totalBalance = Decimal.zero;
  Decimal _totalPL = Decimal.zero;
  Decimal _totalProfit = Decimal.zero;
  Decimal _totalLoss = Decimal.zero;
  Decimal _plPercentage = Decimal.zero;
  Decimal? _customRate;

  bool _isReversed = false;
  bool _isOpen = true;

  Timer? _debounce;

  Decimal? get effectiveMarketRate {
    final m = rateableValue;
    if (m == null) return null;

    return _isReversed ? (m == Decimal.zero ? null : Math.divide(Decimal.one, m)) : m;
  }

  Decimal? get nonReversedEffectiveRate {
    final c = _customRate;
    if (c != null) {
      return _isReversed ? Math.divide(Decimal.one, c) : c;
    }

    final m = rateableValue;
    if (m != null) {
      return m;
    }

    return _calc.averageExchangedRate(txs, reverse: false);
  }

  bool get isCapital => (widget.srid == widget.rrid);
  String get cardKey => "tx-group-active-${widget.srid}-${widget.rrid}";

  @override
  String get sortableKey => cardKey;

  @override
  String get selectableKey => cardKey;

  @override
  void initState() {
    super.initState();

    rateableIsTemporary = false;
    rateableSource = widget.srid;
    rateableTarget = widget.rrid;
    rateableGetRate(refresh: false, silent: true);

    _isOpen = widget.isOpen;
    _customRate = states.get("[np]-$cardKey-custom-rate", defaultValue: null);
    _isReversed = states.get("[np]-$cardKey-is-reversed", defaultValue: false);

    txs = widget.transactions;
    fxs = widget.txsFlags;

    txController = CoreLocator.getit<TransactionsController>();

    _cryptosController = CoreLocator.getit<CryptosController>();
    _sourceSymbol = _cryptosController.getSymbol(widget.srid) ?? 'Unknown Coin';
    _resultSymbol = _cryptosController.getSymbol(widget.rrid) ?? 'Unknown Coin';

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

    checkForClosable();
    checkForDeletable();
    checkForFinalizable();
    checkForRefundable();
    checkForUpdatable();

    _calculateProfitLoss();
    rows = _buildRows();
    sortableApplySorting(pauseRefresh: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      rateableGetRate(refresh: false, silent: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsWidgetsCardsActive oldWidget) {
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

    txs = widget.transactions;
    fxs = widget.txsFlags;

    checkForClosable();
    checkForDeletable();
    checkForFinalizable();
    checkForRefundable();
    checkForUpdatable();

    _calculateProfitLoss();
    rows = _buildRows();
    sortableApplySorting(); // Sortable will call setState!
  }

  @override
  void rateableUpdateRate() {
    rateableGetRate(refresh: false, silent: true);
  }

  @override
  void rateableGetCallback(bool hasNewRate) {
    if (rateableStateUpdater != null) {
      _setCustomRate(rateableValue);
    } else {
      if (_customRate != null) {
        rateableValue = _customRate;
      }
    }

    rateableDefaultHelper = _averageRate.toStringAsFixed(8);

    if (hasNewRate) {
      _calculateProfitLoss();
      rows = _buildRows();
      sortableApplySorting();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsPanel(
      child: rows.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(spacing: 20, children: [_buildHeader(), if (_isOpen) _buildTable()]),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      key: Key("header-${widget.srid}-${widget.rrid}"),
      builder: (context, constraints) {
        if (constraints.maxWidth > 1000) {
          return Row(
            spacing: 20,
            children: [
              WidgetsHeader(
                key: Key("title-${widget.srid}-${widget.rrid}"),
                title: isCapital ? '$_sourceSymbol Capital' : '$_sourceSymbol to $_resultSymbol Trades',
                subtitle: isCapital ? 'Coin ID: ${widget.srid}' : 'Coin ID: ${widget.srid} - ${widget.rrid}',
              ),
              Expanded(child: _buildPanels()),
              _buildActions(),
            ],
          );
        } else {
          return Column(
            spacing: 10,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: WidgetsHeader(
                  key: Key("title-${widget.srid}-${widget.rrid}"),
                  title: isCapital ? '$_sourceSymbol Capital' : '$_sourceSymbol to $_resultSymbol Trades',
                  subtitle: isCapital ? 'Coin ID: ${widget.srid}' : 'Coin ID: ${widget.srid} - ${widget.rrid}',
                  centered: true,
                ),
              ),
              _buildActions(),
              _buildPanels(),
            ],
          );
        }
      },
    );
  }

  Widget _buildActions() {
    final btnIconSize = 18.0;
    final btnSize = const Size(40, 40);
    final btnPadding = EdgeInsets.all(0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
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
                    initialValue: _customRate != null ? Utils.formatSmartDecimal(_customRate!) : "",
                    allowCopy: false,
                    allowRate: true,
                    onRetrievingRate: _rateAmountRetrieveAction,
                    onChanged: _rateAmountChangeAction,
                  ),
                ),

                WidgetsButtonsAction(
                  icon: Icons.swap_horiz,
                  padding: btnPadding,
                  iconSize: btnIconSize,
                  minimumSize: btnSize,
                  tooltip: _isReversed ? "Click to Inverse rate" : "Click to reverse rate",
                  evaluator: _reverseActionEvaluator,
                  onPressed: _reverseRateAction,
                ),
              ],
            ),

          TransactionsWidgetsButtonsBatch(
            parentContext: widget.parentContext,
            srid: widget.srid,
            rrid: widget.rrid,
            txs: txs,
            rate: nonReversedEffectiveRate ?? Decimal.zero,
            balance: _calc.totalActiveSourceBalance(txs),
            linkableKey: "active-screen",
            selectedRows: selectableSelectedRows,
            isOpen: _isOpen,
            isDeletable: isDeletable,
            isClosable: isClosable,
            isFinalizable: isFinalizable,
            isRefundable: isRefundable,
            isUpdatable: isUpdatable,
            onToggleShow: _toggleShowAction,
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final canSelect = !isCapital && rows.length > 1;
    final tableColumns = [
      WidgetsTableColumn(label: Text('Date'), fixedWidth: 100, onSort: sortableSorters[0]),
      WidgetsTableColumn(
        size: ColumnSize.S,
        label: WidgetsHeader(title: (!isCapital) ? 'From ' : 'Amount', subtitle: _sourceSymbol),
        onSort: sortableSorters[1],
      ),
      if (!isCapital)
        WidgetsTableColumn(
          size: ColumnSize.S,
          label: WidgetsHeader(title: 'To ', subtitle: _resultSymbol),
          onSort: sortableSorters[2],
        ),
      if (!isCapital)
        WidgetsTableColumn(
          size: ColumnSize.S,
          label: WidgetsHeader(title: 'Balance ', subtitle: _resultSymbol),
          onSort: sortableSorters[3],
        ),
      if (!isCapital)
        WidgetsTableColumn(
          size: ColumnSize.S,
          label: WidgetsHeader(
            title: 'Ex. Rate ',
            subtitle: _isReversed ? '$_sourceSymbol / $_resultSymbol' : '$_resultSymbol / $_sourceSymbol',
          ),
          onSort: sortableSorters[4],
        ),

      if (_currentRate != Decimal.zero && !isCapital) ...[
        DataColumn2(
          size: ColumnSize.S,
          label: WidgetsHeader(
            title: 'Cu. Rate ',
            subtitle: _isReversed ? '$_sourceSymbol / $_resultSymbol' : '$_resultSymbol / $_sourceSymbol',
          ),
        ),
        WidgetsTableColumn(
          size: ColumnSize.S,
          label: WidgetsHeader(title: 'Cu. Value ', subtitle: _sourceSymbol),
          onSort: sortableSorters[6],
        ),
        WidgetsTableColumn(
          size: ColumnSize.S,
          label: WidgetsHeader(title: 'Profit/Loss ', subtitle: _sourceSymbol),
          onSort: sortableSorters[7],
        ),
        WidgetsTableColumn(
          fixedWidth: 100,
          label: WidgetsHeader(title: 'P/L', subtitle: "%"),
          onSort: sortableSorters[8],
        ),
      ],

      WidgetsTableColumn(
        label: Text('Status '),
        fixedWidth: 80,
        onSort: (_currentRate == Decimal.zero) ? sortableSorters[5] : sortableSorters[9],
      ),
      DataColumn2(label: Text('Actions'), fixedWidth: 100),
    ];

    final tableRows = rows.map((r) {
      final tx = r['tx'] as TransactionsModel;
      final canSelect = tx.isActive || tx.isPartial;
      return DataRow2(
        key: ValueKey(r['uuid']),
        selected: canSelect ? selectableIsSelected(r['uuid']) : false,
        onSelectChanged: canSelect
            ? (v) {
                selectableSetSelected(r['uuid'], v!);
                _calculateProfitLoss();
                sortableApplySorting();
              }
            : null,
        onTap: () {
          TransactionsDialogsDetails.show(context, r['tx']);
        },
        cells: [
          DataCell(WidgetsWithTooltip(Text(r['date']), r['note'], tx.meta['accent_color'])),
          DataCell(Text(r['from'])),

          if (!isCapital) DataCell(Text(r['to'])),
          if (!isCapital) DataCell(Text(r['balance'] ?? '0.0')),
          if (!isCapital) DataCell(Text(r['exchangedRate'] ?? '0.0')),

          if (_currentRate != Decimal.zero && !isCapital) ...[
            DataCell(WidgetsBalanceText(text: r['currentRate'] ?? "-", value: r['profitLevel'], comparator: 0, hidePrefix: true)),
            DataCell(WidgetsBalanceText(text: r['currentValue'] ?? "-", value: r['profitLevel'], comparator: 0, hidePrefix: true)),
            DataCell(WidgetsBalanceText(text: r['profitLoss'] ?? "-", value: r['profitLevel'], comparator: 0)),
            DataCell(WidgetsBalanceText(text: r['profitLossPercentage'] ?? "-", value: r['profitLevel'], comparator: 0)),
          ],

          DataCell(TransactionsWidgetsStatusText(tx.statusEnum)),
          DataCell(
            TransactionsWidgetsButtonsAction(
              parentContext: context,
              key: Key("action-${tx.uuid}"),
              tx: r['tx'],
              cryptosController: _cryptosController,
              txController: txController,
              isTradable: fxsIsTradable(tx),
              isClosable: fxsIsClosable(tx),
              isDeletable: fxsIsDeletable(tx),
              isUpdatable: fxsIsUpdatable(tx),
              isRefundable: fxsIsRefundable(tx),
              isFinalizable: fxsIsFinalizable(tx),
              hasLeaf: fxsHasLeaf(tx),
              hasTradeableLeaf: fxsHasTradeableLeaf(tx),
              onAction: widget.onStatusChanged,
            ),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      width: double.infinity,
      height: tableCalculateHeight(),
      child: WidgetsTableProxy(
        controller: widget.scrollController,
        topOffset: 80,
        headerHeight: AppTheme.tableHeadingRowHeight,
        rowHeight: AppTheme.tableDataRowMinHeight,
        background: AppTheme.panelBg,
        child: DataTable2(
          key: Key("table-active-${widget.srid}-${widget.rrid}"),
          headingCheckboxTheme: widget.theme.checkboxTheme,
          datarowCheckboxTheme: widget.theme.checkboxTheme,
          showHeadingCheckBox: canSelect,
          showCheckboxColumn: canSelect,
          minWidth: 1200,
          columnSpacing: 12,
          horizontalMargin: 12,
          headingRowHeight: tableHeadingHeight,
          dataRowHeight: tableRowHeight,
          sortColumnIndex: (_currentRate == Decimal.zero && sortableColumnIndex > 4) ? null : sortableColumnIndex,
          sortAscending: sortableAscending,
          isHorizontalScrollBarVisible: false,
          columns: tableColumns,
          rows: tableRows,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildRows() {
    final currentRate = _customRate ?? effectiveMarketRate ?? Decimal.zero;
    final rx = <Map<String, dynamic>>[];

    for (final tx in txs) {
      Decimal rowRate = currentRate;
      Decimal currentValue = Decimal.zero;
      Decimal profitLoss = Decimal.zero;
      Decimal currentSrAmount = tx.srAmount;
      Decimal profitLossPercentage = Decimal.zero;

      double profitLevel = 0;

      if (tx.isFinalized) {
        profitLoss = Decimal.zero;
        profitLevel = 0;
        rowRate = tx.rate;
        currentValue = tx.balance;
      } else if (currentRate != Decimal.zero && tx.balance != Decimal.zero && !tx.isClosed) {
        if (tx.isPartial) {
          currentSrAmount = Math.multiply(Math.divide(tx.balance, tx.rrAmount), tx.srAmount);
        }

        currentValue = _isReversed ? Math.multiply(tx.balance, currentRate) : Math.divide(tx.balance, currentRate);
        profitLoss = Math.subtract(currentValue, currentSrAmount);
        profitLossPercentage = Math.multiply(Math.divide(profitLoss, currentSrAmount), Decimal.fromInt(100));

        if (profitLoss > Decimal.zero) {
          profitLevel = 1;
        } else if (profitLoss < Decimal.zero) {
          profitLevel = -1;
        }
      }

      rx.add({
        'from': tx.srAmountText,
        'to': tx.rrAmountText,
        'balance': tx.balanceText,
        'exchangedRate': _isReversed ? tx.rateReversedText : tx.rateText,
        'currentRate': currentRate == Decimal.zero ? null : Utils.formatSmartDecimal(rowRate),
        'currentValue': currentRate == Decimal.zero ? null : Utils.formatSmartDecimal(currentValue),
        'profitLoss': currentRate == Decimal.zero ? null : Utils.formatSmartDecimal(profitLoss),
        'profitLossPercentage': currentRate == Decimal.zero ? null : Utils.formatSmartDecimal(profitLossPercentage, maxDecimals: 2),
        'profitLevel': profitLevel,
        'status': tx.statusText,
        'date': tx.timestampAsFormattedDate,
        'tx': tx,
        'note': tx.noteText,
        'uuid': tx.uuid,

        '_note': tx.noteText,
        '_timestamp': tx.sanitizedTimestamp,
        '_targetValue': tx.rrAmount,
        '_sourceValue': tx.srAmount,
        '_balanceValue': tx.balance,
        '_exchangedRateValue': tx.rate,
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
                TransactionsWidgetsPanelItem(
                  title: 'Total Balance',
                  subtitle: isCapital
                      ? '${Utils.formatSmartDecimal(_totalBalance)} $_sourceSymbol'
                      : '${Utils.formatSmartDecimal(_totalSourceBalance)} $_sourceSymbol - ${Utils.formatSmartDecimal(_totalBalance)} $_resultSymbol',
                  value: 0,
                  comparator: 0,
                ),

                if (!isCapital)
                  TransactionsWidgetsPanelItem(
                    title: 'Avg Rate',
                    subtitle: Utils.formatSmartDecimal(_averageRate),
                    value: 0,
                    comparator: 0,
                  ),

                if (_plPercentage != Decimal.zero && !isCapital) ...[
                  if (_totalProfit != Decimal.zero && _totalLoss != Decimal.zero)
                    TransactionsWidgetsPanelItem(
                      title: 'Profit',
                      subtitle: Utils.formatSmartDecimal(_totalProfit),
                      value: _totalProfit.toDouble(),
                      comparator: 0,
                    ),

                  if (_totalProfit != Decimal.zero && _totalLoss != Decimal.zero)
                    TransactionsWidgetsPanelItem(
                      title: 'Loss',
                      subtitle: Utils.formatSmartDecimal(_totalLoss),
                      value: _totalLoss.toDouble(),
                      comparator: 0,
                    ),

                  TransactionsWidgetsPanelItem(
                    title: 'Total P/L',
                    subtitle: "${Utils.formatSmartDecimal(_totalPL)} $_sourceSymbol",
                    value: _plPercentage.toDouble(),
                    comparator: 0,
                  ),

                  TransactionsWidgetsPanelItem(
                    title: 'P/L %',
                    subtitle: '${Utils.formatSmartDecimal(_plPercentage, maxDecimals: 2)}%',
                    value: _plPercentage.toDouble(),
                    comparator: 0,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _calculateProfitLoss() {
    final stxs = [...txs];

    if (selectableHasSelectedRows()) {
      final selectedTxIds = selectableGetSelectedRows();
      stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));
    }

    final atxs = stxs.where((tx) => tx.isActive || tx.isPartial).toList();

    _averageRate = _calc.averageExchangedRate(stxs, reverse: _isReversed);
    _currentRate = _customRate ?? effectiveMarketRate ?? Decimal.zero;
    _totalSourceBalance = _calc.totalSourceBalance(stxs, shrinkPartial: true);
    _totalBalance = _calc.totalBalance(stxs);
    _totalPL = _calc.totalProfitLoss(atxs, _currentRate, reverse: _isReversed, shrinkPartial: true);
    _totalProfit = _calc.totalProfit(atxs, _currentRate, reverse: _isReversed, shrinkPartial: true);
    _totalLoss = _calc.totalLoss(atxs, _currentRate, reverse: _isReversed, shrinkPartial: true);
    _plPercentage = _calc.profitLossPercentage(atxs, _currentRate, reverse: _isReversed, shrinkPartial: true);
  }

  void _reverseRateAction(WidgetsButtonsActionState s) {
    _isReversed = !_isReversed;
    if (_customRate != null) {
      _setCustomRate(Math.divide(Decimal.one, _customRate!));
    }

    // BugFix: Dont link to rateable to prevent double inversing!
    _currentRate = _customRate ?? effectiveMarketRate ?? Decimal.zero;
    _calculateProfitLoss();
    rows = _buildRows();
    sortableApplySorting();

    states.set("[np]-$cardKey-is-reversed", _isReversed);
  }

  void _reverseActionEvaluator(WidgetsButtonsActionState s) {
    if (_isReversed) {
      s.action();
    } else {
      s.normal();
    }
  }

  void _rateAmountChangeAction(String value) {
    // Nullify the promise contract!
    rateableStateUpdater = null;

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final newValue = Decimal.tryParse(value);
    if (_customRate != newValue) {
      _debounce = Timer(Duration(milliseconds: 100), () {
        _setCustomRate(newValue);
        rateableGetRate(refresh: false, silent: true);
      });
    }
  }

  void _rateAmountRetrieveAction(void Function(String value, String helperText) updateState) {
    // Store the callback to act as promise contract!
    rateableStateUpdater = updateState;
    rateableStateUpdater?.call("", "Retrieving rate...");
    rateableGetRate(refresh: false, reversed: _isReversed);
  }

  void _toggleShowAction(WidgetsButtonsActionState b) {
    setState(() {
      _isOpen = !_isOpen;
      states.set("tx-group-active-open-$rateableSource-$rateableTarget", _isOpen);
    });

    widget.onToggleChanged.call();
  }

  void _setCustomRate(Decimal? rate) {
    _customRate = rate;
    if (_customRate == null) {
      states.remove("[np]-$cardKey-custom-rate");
    } else {
      states.set("[np]-$cardKey-custom-rate", _customRate);
    }
  }
}
