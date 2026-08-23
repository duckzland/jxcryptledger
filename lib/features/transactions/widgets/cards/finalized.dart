import 'package:data_table_2/data_table_2.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/locator.dart';
import '../../../../core/math.dart';
import '../../../../core/utils.dart';
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
import '../../controller.dart';
import '../../dialogs/details.dart';
import '../../calculations.dart';
import '../../mixins/actions.dart';
import '../../mixins/flags.dart';
import '../../mixins/sortable_table.dart';
import '../../model.dart';
import '../buttons/action.dart';
import '../buttons/batch.dart';
import '../panel_item.dart';

class TransactionsWidgetsCardsFinalized extends StatefulWidget {
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

  const TransactionsWidgetsCardsFinalized({
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
  State<TransactionsWidgetsCardsFinalized> createState() => _TransactionsWidgetsCardsFinalizedState();
}

class _TransactionsWidgetsCardsFinalizedState extends State<TransactionsWidgetsCardsFinalized>
    with
        MixinsState,
        MixinsTable,
        MixinsSelectableTable,
        MixinsSortableTable<TransactionsWidgetsCardsFinalized>,
        TransactionsMixinsSortableTable<TransactionsWidgetsCardsFinalized>,
        TransactionsMixinsActions,
        TransactionsMixinsFlags {
  final TransactionCalculation _calc = TransactionCalculation();

  CryptosController get _cryptosController => CoreLocator.getit<CryptosController>();

  late String _resultSymbol;

  Decimal _capitalTotal = Decimal.zero;
  Decimal _capitalUsed = Decimal.zero;

  Map<int, Decimal> _finalizedBalance = {};

  bool _isOpen = true;

  @override
  String get sortableKey => "tx-group-finalized-${widget.id}";

  @override
  String get selectableKey => "tx-group-finalized-${widget.id}";

  @override
  ValueNotifier<List<String>>? get selectableGroupRows => widget.selectableGroup;

  @override
  bool selectableIsValidKey(String key) {
    return txs.isEmpty ? false : txs.any((tx) => tx.uuid == key);
  }

  @override
  void initState() {
    super.initState();

    txController = CoreLocator.getit<TransactionsController>();

    txs = widget.transactions;
    fxs = widget.txsFlags;

    _isOpen = widget.isOpen;
    _resultSymbol = _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin';

    checkForClosable();
    checkForDeletable();
    checkForFinalizable();
    checkForRefundable();
    checkForUpdatable();

    _calculatePanelData();
    rows = _buildRows();
    sortableApplySorting(pauseRefresh: true);
    selectableSyncWithGroup();
  }

  @override
  void didUpdateWidget(covariant TransactionsWidgetsCardsFinalized oldWidget) {
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

    _calculatePanelData();
    rows = _buildRows();
    sortableApplySorting();
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
      rrid: 0,
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 20,
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
    final capitalTotal = TransactionsWidgetsPanelItem(
      title: "Capital",
      subtitle: "${Utils.formatSmartDecimal(_capitalTotal)} $_resultSymbol",
    );

    final capitalFinalized = TransactionsWidgetsPanelItem(
      title: "Finalized",
      subtitle: "${Utils.formatSmartDecimal(_capitalUsed)} $_resultSymbol",
    );

    final finalizedPanels = _finalizedBalance.entries.map((e) {
      final rrId = e.key;
      final total = e.value;
      final symbol = _cryptosController.getSymbol(rrId) ?? "UNK";

      return TransactionsWidgetsPanelItem(title: symbol, subtitle: Utils.formatSmartDecimal(total));
    }).toList();

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
              children: [capitalTotal, capitalFinalized, ...finalizedPanels],
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
      WidgetsTableColumn(label: Text('To '), size: ColumnSize.M, onSort: sortableSorters["rrAmount"]),
      WidgetsTableColumn(label: Text('Balance '), size: ColumnSize.M, onSort: sortableSorters["balance"]),
      WidgetsTableColumn(label: Text('Rate '), size: ColumnSize.M, onSort: sortableSorters["rate"]),
      WidgetsTableColumn(label: Text('Capital Used '), size: ColumnSize.M, onSort: sortableSorters["capital"]),
      DataColumn2(label: Text('Actions '), fixedWidth: 100),
    ];
    final tableRows = rows.map((r) {
      final tx = r['tx'] as TransactionsModel;

      return DataRow2(
        key: ValueKey(tx.uuid),
        selected: selectableIsSelected(tx.uuid),
        onSelectChanged: (v) {
          selectableSetSelected(tx.uuid, v!);
          _calculatePanelData();
          sortableApplySorting();
        },
        onTap: () {
          TransactionsDialogsDetails.show(context, tx);
        },
        cells: [
          DataCell(WidgetsWithTooltip(WidgetsTextSelectable(tx.timestampAsFormattedDate), tx.noteText, tx.meta['accent_color'])),
          DataCell(WidgetsTextSelectable(r['from'])),

          DataCell(WidgetsTextSelectable(r['to'])),

          DataCell(WidgetsTextSelectable(r['balance'])),

          DataCell(WidgetsTextSelectable(r['rate'])),

          DataCell(WidgetsTextSelectable(r['capital'])),

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
          key: Key("table-finalized-${widget.id}"),
          headingCheckboxTheme: widget.theme.checkboxTheme,
          datarowCheckboxTheme: widget.theme.checkboxTheme,
          showHeadingCheckBox: true,
          showCheckboxColumn: true,
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
      final resultCoinSymbol = _cryptosController.getSymbol(tx.rrId);
      final capitalUsed = _calc.totalCapitalUsed(tx, txsMap: txsMap);

      rx.add({
        'date': tx.timestampAsFormattedDate,
        'from': '${tx.srAmountText} $sourceCoinSymbol',
        'to': '${tx.rrAmountText} $resultCoinSymbol',
        'balance': '${tx.balanceText} $resultCoinSymbol',
        'rate': '${tx.rateText} $sourceCoinSymbol/$resultCoinSymbol',
        'capital': tx.isCapital ? ' - ' : "${Utils.formatSmartDecimal(capitalUsed)} $_resultSymbol",
        'tx': tx,

        '_capitalUsed': tx.isCapital ? 0.0 : capitalUsed.toDouble(),
        '_exchangedRateValue': tx.rate.toDouble(),
        '_sourceSymbol': sourceCoinSymbol,
        '_resultSymbol': resultCoinSymbol,
      });
    }

    return rx;
  }

  void _calculatePanelData() {
    if (txs.isEmpty) {
      return;
    }

    final stxs = [...txs];
    final txsMap = txController.getIndexedMap();

    if (selectableHasSelectedRows()) {
      final selectedTxIds = selectableGetSelectedRows();
      stxs.retainWhere((tx) => selectedTxIds.contains(tx.uuid));
    }

    Decimal capital = Decimal.zero;
    final Map<String, TransactionsModel> roots = {};
    for (final rtx in stxs) {
      final root = txController.getRoot(rtx);
      if (root != null) {
        roots[root.tid] = root;
      }
    }
    for (final txx in roots.entries) {
      final rtx = txx.value;
      if (rtx.srId == widget.id) {
        capital = Math.add(capital, rtx.srAmount);
      }
    }

    Decimal used = Decimal.zero;
    for (final rtx in stxs) {
      used = Math.add(used, _calc.totalCapitalUsed(rtx, txsMap: txsMap));
    }

    final finalizedBalance = _calc.totalFinalizedGroup(stxs);

    _capitalTotal = capital;
    _capitalUsed = used;
    _finalizedBalance = finalizedBalance;
  }

  void _toggleShowAction(WidgetsButtonsActionState b) {
    setState(() {
      _isOpen = !_isOpen;
      states.set("tx-group-finalized-open-${widget.id}", _isOpen);
    });

    widget.onToggleChanged.call();
  }
}
