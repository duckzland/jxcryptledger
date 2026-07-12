import 'dart:ui';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../../app/scroll_behavior.dart';
import '../../../../core/runtime/locator.dart';
import '../../../../core/math.dart';
import '../../../../core/utils.dart';
import '../../../../mixins/actionable.dart';
import '../../../../mixins/selectable_table.dart';
import '../../../../mixins/sortable_table.dart';
import '../../../../mixins/state.dart';
import '../../../../mixins/table.dart';
import '../../../../widgets/button.dart';
import '../../../../widgets/header.dart';
import '../../../../widgets/panel.dart';
import '../../../../widgets/with_tooltip.dart';
import '../../../cryptos/controller.dart';
import '../../dialogs/details.dart';
import '../../mixins/actions.dart';
import '../../calculations.dart';
import '../../controller.dart';
import '../../mixins/flags.dart';
import '../../model.dart';
import '../buttons/batch.dart';
import '../buttons/action.dart';
import '../panel_item.dart';
import '../status_text.dart';

class TransactionsWidgetsCardsOverview extends StatefulWidget {
  final int id;
  final List<TransactionsModel> transactions;
  final Map<String, Map<TransactionsFlagsType, bool>> txsFlags;

  final VoidCallback onStatusChanged;
  final VoidCallback onToggleChanged;

  final BuildContext parentContext;

  final bool isOpen;

  const TransactionsWidgetsCardsOverview({
    super.key,
    required this.parentContext,
    required this.id,
    required this.transactions,
    required this.txsFlags,
    required this.onStatusChanged,
    required this.onToggleChanged,
    required this.isOpen,
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
        TransactionsMixinsActions,
        TransactionsMixinsFlags {
  final TransactionCalculation _calc = TransactionCalculation();

  CryptosController get _cryptosController => locator<CryptosController>();

  late String _resultSymbol;

  double _totalCapital = 0;
  double _currentHolding = 0;
  double _finalizedBalance = 0;
  double _profitLoss = 0;
  double _profitLossPercentage = 0;

  bool _isOpen = true;

  @override
  String get sortableKey => "tx-group-overview-${widget.id}";

  @override
  void initState() {
    super.initState();

    txController = locator<TransactionsController>();

    _isOpen = widget.isOpen;

    txs = widget.transactions;
    fxs = widget.txsFlags;

    _resultSymbol = _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin';

    sortableSorters = {
      0: (col, asc) => sortableOnSort((d) => d['_timestamp'] as int, col, asc),
      1: (col, asc) => sortableOnSort((d) => d['_balanceValue'] as double, col, asc),
      2: (col, asc) => sortableOnSort((d) => d['_sourceValue'] as double, col, asc),
      3: (col, asc) => sortableOnSort((d) => d['_exchangedRateValue'] as double, col, asc),
      4: (col, asc) => sortableOnSort((d) => d['status'] as String, col, asc),
    };

    checkForClosable();
    checkForDeletable();
    checkForFinalizable();
    checkForRefundable();

    _calculateProfitLoss();
    rows = _buildRows();
    sortableApplySorting();
  }

  @override
  void dispose() {
    super.dispose();
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

    _calculateProfitLoss();
    rows = _buildRows();
    sortableApplySorting();
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsPanel(child: Column(spacing: 20, children: [_buildHeader(), if (_isOpen) _buildTable()]));
  }

  Widget _buildHeader() {
    final title = Padding(
      padding: const EdgeInsets.only(top: 5),
      child: WidgetsHeader(
        key: Key("title-${widget.id}"),
        title: _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin',
        subtitle: 'Coin ID: ${widget.id}',
      ),
    );

    final actions = TransactionsWidgetsButtonsBatch(
      parentContext: widget.parentContext,
      srid: widget.id,
      rrid: 0,
      txs: txs,
      selectedRows: selectableSelectedRows,
      isOpen: _isOpen,
      isDeletable: isDeletable,
      isClosable: isClosable,
      isFinalizable: isFinalizable,
      isRefundable: isRefundable,
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
              Row(spacing: 10, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [title, actions]),
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
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse}),
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
                  if (_totalCapital > 0)
                    TransactionsWidgetsPanelItem(
                      title: "Total Capital",
                      subtitle: "${Utils.formatSmartDouble(_totalCapital)} $_resultSymbol",
                      value: 0,
                      comparator: 0,
                    ),
                  if (_currentHolding > 0)
                    TransactionsWidgetsPanelItem(
                      title: "Current Balance",
                      subtitle: "${Utils.formatSmartDouble(_currentHolding)} $_resultSymbol",
                      value: 0,
                      comparator: 0,
                    ),
                  if (_finalizedBalance > 0)
                    TransactionsWidgetsPanelItem(
                      title: "Finalized Balance",
                      subtitle: "${Utils.formatSmartDouble(_finalizedBalance)} $_resultSymbol",
                      value: 0,
                      comparator: 0,
                    ),
                  if (_totalCapital > 0 && _profitLossPercentage != 0)
                    TransactionsWidgetsPanelItem(
                      title: "Profit/Loss",
                      subtitle: "${Utils.formatSmartDouble(_profitLoss)} $_resultSymbol",
                      value: _profitLossPercentage,
                      comparator: 0,
                    ),
                  if (_totalCapital > 0 && _profitLossPercentage != 0)
                    TransactionsWidgetsPanelItem(
                      title: "Profit/Loss %",
                      subtitle: "${Utils.formatSmartDouble(_profitLossPercentage, maxDecimals: 2)}%",
                      value: _profitLossPercentage,
                      comparator: 0,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    final canSelect = isActive && rows.length > 1;
    final theme = Theme.of(context);
    final checkboxTheme = theme.checkboxTheme;
    final tableColumns = [
      DataColumn2(label: const Text('Date'), fixedWidth: 100, onSort: sortableSorters[0]),
      DataColumn2(label: const Text('From'), size: ColumnSize.M, onSort: sortableSorters[2]),
      DataColumn2(label: const Text('Balance'), size: ColumnSize.M, onSort: sortableSorters[1]),
      DataColumn2(label: const Text('Exchanged Rate'), size: ColumnSize.S, onSort: sortableSorters[3]),
      DataColumn2(label: const Text('Status'), fixedWidth: 100, onSort: sortableSorters[4]),
      const DataColumn2(label: Text('Actions'), fixedWidth: 160),
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
          DataCell(WidgetsWithTooltip(Text(r['date']), r['note'])),
          DataCell(Text(r['source'])),
          DataCell(Text(r['balance'])),
          DataCell(Text(r['exchangedRate'])),
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
      child: ScrollConfiguration(
        behavior: const AppScrollBehavior(),
        child: DataTable2(
          key: Key("table-${widget.id}"),
          headingCheckboxTheme: checkboxTheme,
          datarowCheckboxTheme: checkboxTheme,
          showHeadingCheckBox: canSelect,
          showCheckboxColumn: canSelect,
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

    for (final tx in txs) {
      final sourceCoinSymbol = _cryptosController.getSymbol(tx.srId);

      rx.add({
        'balance': '${tx.balanceText} $_resultSymbol',
        'source': tx.isCapital ? 'Capital' : '${tx.srAmountText} $sourceCoinSymbol to ${tx.rrAmountText} $_resultSymbol',
        'exchangedRate': tx.isCapital ? ' - ' : '${tx.rateText} $_resultSymbol/$sourceCoinSymbol',
        'status': tx.statusText,
        'date': tx.timestampAsFormattedDate,
        'tx': tx,
        'uuid': tx.uuid,
        'note': tx.noteText,

        '_note': tx.noteText,
        '_timestamp': tx.sanitizedTimestamp,
        '_balanceValue': tx.balance,
        '_sourceValue': tx.srAmount,
        '_exchangedRateValue': tx.rateDouble,
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
    double capital = 0;
    final roots = txController.collectAllRoots();
    for (final rtx in roots) {
      if (rtx.srId == widget.id) {
        capital = Math.add(capital, rtx.srAmount);
      }
    }

    final finalizedBalance = _calc.totalFinalizedBalance(stxs);
    final balance = _calc.totalActiveBalance(stxs);
    final totalBalance = Math.add(balance, finalizedBalance);
    final profitPercentage = (capital == 0) ? 0.0 : (Math.divide(Math.subtract(totalBalance, capital), capital) * 100);

    _totalCapital = capital;
    _currentHolding = balance;
    _finalizedBalance = finalizedBalance;
    _profitLoss = Math.subtract(totalBalance, capital);
    _profitLossPercentage = profitPercentage;
  }

  void _toggleShowAction(WidgetsButtonState b) {
    setState(() {
      _isOpen = !_isOpen;
      states.set("tx-group-overview-open-${widget.id}", _isOpen);
    });

    widget.onToggleChanged.call();
  }
}
