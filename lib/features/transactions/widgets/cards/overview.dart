import 'package:data_table_2/data_table_2.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/locator.dart';
import '../../../../core/math.dart';
import '../../../../core/utils.dart';
import '../../../../mixins/actionable.dart';
import '../../../../mixins/rateable.dart';
import '../../../../mixins/selectable_table.dart';
import '../../../../mixins/sortable_table.dart';
import '../../../../mixins/state.dart';
import '../../../../mixins/table.dart';
import '../../../../widgets/buttons/action.dart';
import '../../../../widgets/header.dart';
import '../../../../widgets/panel.dart';
import '../../../../widgets/table/column.dart';
import '../../../../widgets/table/proxy.dart';
import '../../../../widgets/text/selectable.dart';
import '../../../../widgets/with_tooltip.dart';
import '../../../cryptos/controller.dart';
import '../../dialogs/details.dart';
import '../../mixins/actions.dart';
import '../../calculations.dart';
import '../../controller.dart';
import '../../mixins/flags.dart';
import '../../mixins/sortable_table.dart';
import '../../model.dart';
import '../buttons/batch.dart';
import '../buttons/action.dart';
import '../panel_item.dart';
import '../status_text.dart';

class TransactionsWidgetsCardsOverview extends StatefulWidget {
  final int id;
  final List<TransactionsModel> transactions;
  final Map<String, Map<TransactionsFlagsType, bool>> txsFlags;
  final ValueNotifier<List<String>> selectableGroup;

  final VoidCallback onStatusChanged;
  final VoidCallback onToggleChanged;

  final BuildContext parentContext;

  final ThemeData theme;

  final bool isOpen;

  final ScrollController scrollController;

  const TransactionsWidgetsCardsOverview({
    super.key,
    required this.parentContext,
    required this.theme,
    required this.id,
    required this.transactions,
    required this.txsFlags,
    required this.onStatusChanged,
    required this.onToggleChanged,
    required this.isOpen,
    required this.scrollController,
    required this.selectableGroup,
  });

  @override
  State<TransactionsWidgetsCardsOverview> createState() => _TransactionsWidgetsCardsOverviewState();
}

class _TransactionsWidgetsCardsOverviewState extends State<TransactionsWidgetsCardsOverview>
    with
        MixinsActionable,
        MixinsState,
        MixinsTable,
        MixinsSelectableTable,
        MixinsSortableTable<TransactionsWidgetsCardsOverview>,
        MixinsRateable<TransactionsWidgetsCardsOverview>,
        TransactionsMixinsSortableTable<TransactionsWidgetsCardsOverview>,
        TransactionsMixinsActions,
        TransactionsMixinsFlags {
  final TransactionCalculation _calc = TransactionCalculation();

  CryptosController get _cryptosController => CoreLocator.getit<CryptosController>();

  late String _resultSymbol;

  Decimal _totalCapital = Decimal.zero;
  Decimal _currentHolding = Decimal.zero;
  Decimal _currentUsd = Decimal.zero;
  Decimal _finalizedBalance = Decimal.zero;
  Decimal _profitLoss = Decimal.zero;
  Decimal _profitLossPercentage = Decimal.zero;

  bool _isOpen = true;

  @override
  String get sortableKey => "tx-group-overview-${widget.id}";

  @override
  String get selectableKey => "tx-group-overview-${widget.id}";

  @override
  ValueNotifier<List<String>>? get selectableGroupRows => widget.selectableGroup;

  @override
  void initState() {
    super.initState();

    txController = CoreLocator.getit<TransactionsController>();

    _isOpen = widget.isOpen;

    txs = widget.transactions;
    fxs = widget.txsFlags;

    _resultSymbol = _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin';

    rateableIsTemporary = false;
    rateableWithField = false;
    rateableSource = widget.id;
    rateableTarget = 825;
    rateableGetRate(refresh: false, silent: true);

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
  void didUpdateWidget(covariant TransactionsWidgetsCardsOverview oldWidget) {
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

    rateableGetRate(refresh: false, silent: true);

    _calculateProfitLoss();
    rows = _buildRows();
    sortableApplySorting();
  }

  @override
  void rateableUpdateRate() {
    rateableGetRate(refresh: false, silent: true);
  }

  @override
  void rateableGetCallback(bool hasNewRate) {
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
    final title = Padding(
      padding: EdgeInsets.only(top: 5),
      child: WidgetsHeader(
        key: Key("title-${widget.id}"),
        title: _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin',
        subtitle: 'Coin ID: ${widget.id}',
      ),
    );

    final actions = TransactionsWidgetsButtonsBatch(
      parentContext: widget.parentContext,
      srid: 0,
      rrid: widget.id,
      txs: txs,
      selectedRows: selectableSelectedRows,
      isOpen: _isOpen,
      isDeletable: isDeletable,
      isClosable: isClosable,
      isFinalizable: isFinalizable,
      isRefundable: isRefundable,
      isUpdatable: isUpdatable,
      onToggleShow: _toggleShowAction,
    );

    return LayoutBuilder(
      key: Key("header-${widget.id}"),
      builder: (context, constraints) {
        if (constraints.maxWidth > 560) {
          return Row(
            spacing: 20,
            children: [
              title,
              Expanded(child: _buildPanels()),
              actions,
            ],
          );
        } else {
          return Column(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 42,
                child: CustomScrollView(
                  scrollDirection: Axis.horizontal,
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          title,
                          Expanded(flex: 2, child: SizedBox(width: 30)),
                          actions,
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _buildPanels(),
            ],
          );
        }
      },
    );
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
              key: Key("panels-${widget.id}"),
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              spacing: 16,
              children: [
                if (_totalCapital > Decimal.zero)
                  TransactionsWidgetsPanelItem(
                    title: "Total Capital",
                    subtitle: "${Utils.formatSmartDecimal(_totalCapital)} $_resultSymbol",
                  ),
                if (_currentUsd > Decimal.zero)
                  TransactionsWidgetsPanelItem(
                    title: "Balance",
                    subtitle: "${Utils.formatSmartDecimal(_currentUsd, limitDecimals: 2)} USDT",
                  ),
                if (_currentHolding > Decimal.zero)
                  TransactionsWidgetsPanelItem(
                    title: "Current Balance",
                    subtitle: "${Utils.formatSmartDecimal(_currentHolding)} $_resultSymbol",
                  ),
                if (_finalizedBalance > Decimal.zero)
                  TransactionsWidgetsPanelItem(
                    title: "Finalized Balance",
                    subtitle: "${Utils.formatSmartDecimal(_finalizedBalance)} $_resultSymbol",
                  ),
                if (_totalCapital > Decimal.zero && _profitLossPercentage != Decimal.zero)
                  TransactionsWidgetsPanelItem(
                    title: "Profit/Loss",
                    subtitle: "${Utils.formatSmartDecimal(_profitLoss)} $_resultSymbol",
                    value: _profitLossPercentage.toDouble(),
                  ),
                if (_totalCapital > Decimal.zero && _profitLossPercentage != Decimal.zero)
                  TransactionsWidgetsPanelItem(
                    title: "Profit/Loss %",
                    subtitle: "${Utils.formatSmartDecimal(_profitLossPercentage, maxDecimals: 2)}%",
                    value: _profitLossPercentage.toDouble(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final tableColumns = [
      WidgetsTableColumn(label: Text('Date '), fixedWidth: 100, onSort: sortableSorters["timestamp"]),
      WidgetsTableColumn(label: Text('From '), size: ColumnSize.M, onSort: sortableSorters["srAmount"]),
      WidgetsTableColumn(
        label: WidgetsHeader(title: 'To ', subtitle: _resultSymbol),
        size: ColumnSize.M,
        onSort: sortableSorters["rrAmount"],
      ),
      WidgetsTableColumn(
        label: WidgetsHeader(title: 'Balance ', subtitle: _resultSymbol),
        size: ColumnSize.S,
        onSort: sortableSorters["balance"],
      ),
      WidgetsTableColumn(
        label: WidgetsHeader(title: 'Balance ', subtitle: 'USDT'),
        size: ColumnSize.S,
        onSort: sortableSorters["balance"],
      ),
      WidgetsTableColumn(label: Text('Exchanged Rate '), size: ColumnSize.M, onSort: sortableSorters["rate"]),
      WidgetsTableColumn(
        size: ColumnSize.S,
        label: WidgetsHeader(title: 'Capital Used '),
        onSort: sortableSorters["capital"],
      ),
      WidgetsTableColumn(label: Text('Status '), fixedWidth: 80, onSort: sortableSorters["status"]),
      DataColumn2(label: Text('Actions '), fixedWidth: 100),
    ];
    final tableRows = rows.map((r) {
      final tx = r['tx'] as TransactionsModel;
      final canSelect = tx.isActive || tx.isPartial;

      return DataRow2(
        key: ValueKey(tx.uuid),
        selected: canSelect ? selectableIsSelected(tx.uuid) : false,
        onSelectChanged: canSelect
            ? (v) {
                selectableSetSelected(tx.uuid, v!);
                _calculateProfitLoss();
                sortableApplySorting();
              }
            : null,
        onTap: () {
          TransactionsDialogsDetails.show(context, tx);
        },
        cells: [
          DataCell(WidgetsWithTooltip(WidgetsTextSelectable(tx.timestampAsFormattedDate), tx.noteText, tx.meta['accent_color'])),
          DataCell(WidgetsTextSelectable(r['source'])),

          DataCell(WidgetsTextSelectable(tx.rrAmountText)),

          DataCell(WidgetsTextSelectable(tx.balanceText)),

          DataCell(WidgetsTextSelectable(r['usd'])),

          DataCell(WidgetsTextSelectable(r['rate'])),

          DataCell(WidgetsTextSelectable(r['capital'])),

          DataCell(TransactionsWidgetsStatusText(tx.statusEnum)),
          DataCell(
            TransactionsWidgetsButtonsAction(
              parentContext: context,
              key: Key("action-${tx.uuid}"),
              tx: tx,
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
          key: Key("table-overview-${widget.id}"),
          headingCheckboxTheme: widget.theme.checkboxTheme,
          datarowCheckboxTheme: widget.theme.checkboxTheme,
          showHeadingCheckBox: isActive,
          showCheckboxColumn: isActive,
          minWidth: 1200,
          columnSpacing: 12,
          horizontalMargin: 12,
          headingRowHeight: tableHeadingHeight,
          dataRowHeight: tableRowHeight,
          sortColumnIndex: sortableColumnIndex,
          sortAscending: sortableAscending,
          isHorizontalScrollBarVisible: false,
          columns: tableColumns,
          rows: tableRows,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildRows() {
    final rx = <Map<String, dynamic>>[];
    final txsMap = txController.getIndexedMap();

    for (final tx in txs) {
      final sourceCoinSymbol = _cryptosController.getSymbol(tx.srId);
      final usdValue = Math.multiply(tx.balance, rateableValue ?? Decimal.zero);
      final capitalUsed = _calc.totalCapitalUsed(tx, txsMap: txsMap);
      final root = tx.isRoot ? tx : txController.getRoot(tx);
      final rootSymbol = _cryptosController.getSymbol(root?.srId ?? 0);

      rx.add({
        'source': tx.isCapital ? 'Capital' : '${tx.srAmountText} $sourceCoinSymbol',
        'rate': tx.isCapital ? ' - ' : '${tx.rateText} $_resultSymbol/$sourceCoinSymbol',
        'usd': usdValue != Decimal.zero ? Utils.formatSmartDecimal(usdValue, limitDecimals: 2) : '-',
        'capital': "${Utils.formatSmartDecimal(capitalUsed)} $rootSymbol",
        'tx': tx,

        '_usd': usdValue.toDouble(),
        '_capitalUsed': capitalUsed.toDouble(),
        '_capitalSymbol': rootSymbol,
        '_sourceSymbol': sourceCoinSymbol,
      });
    }

    return rx;
  }

  void _calculateProfitLoss() {
    if (txs.isEmpty) {
      return;
    }

    final stxs = [...txs];

    if (selectableHasSelectedRows()) {
      final selectedTxIds = selectableGetSelectedRows();
      stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));
    }

    // Extract all roots for the same srId as this group!
    Decimal capital = Decimal.zero;
    final roots = txController.collectAllRoots();
    for (final rtx in roots) {
      if (rtx.srId == widget.id) {
        capital = Math.add(capital, rtx.srAmount);
      }
    }

    final finalizedBalance = _calc.totalFinalizedBalance(stxs);
    final balance = _calc.totalActiveBalance(stxs);
    final totalBalance = Math.add(balance, finalizedBalance);
    final profitPercentage = (capital == Decimal.zero)
        ? Decimal.zero
        : (Math.divide(Math.subtract(totalBalance, capital), capital) * Decimal.fromInt(100));

    _totalCapital = capital;
    _currentHolding = balance;
    _finalizedBalance = finalizedBalance;
    _profitLoss = Math.subtract(totalBalance, capital);
    _profitLossPercentage = profitPercentage;

    _currentUsd = Decimal.zero;
    if (rateableValue != null) {
      for (final tx in stxs) {
        final txUsd = Math.multiply(tx.balance, rateableValue ?? Decimal.zero);
        _currentUsd = Math.add(_currentUsd, txUsd);
      }
    }
  }

  void _toggleShowAction(WidgetsButtonsActionState b) {
    setState(() {
      _isOpen = !_isOpen;
      states.set("tx-group-overview-open-${widget.id}", _isOpen);
    });

    widget.onToggleChanged.call();
  }
}
