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
import '../../../../widgets/with_tooltip.dart';
import '../../../cryptos/controller.dart';
import '../../dialogs/details.dart';
import '../../calculations.dart';
import '../../controller.dart';
import '../../model.dart';
import '../buttons/batch.dart';
import '../panel_item.dart';

class TransactionsWidgetsCardsFinalized extends StatefulWidget {
  final int id;
  final List<TransactionsModel> transactions;

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
    required this.onStatusChanged,
    required this.onToggleChanged,
    required this.isOpen,
    required this.scrollController,
  });

  @override
  State<TransactionsWidgetsCardsFinalized> createState() => _TransactionsWidgetsCardsFinalizedState();
}

class _TransactionsWidgetsCardsFinalizedState extends State<TransactionsWidgetsCardsFinalized>
    with MixinsState, MixinsTable, MixinsSelectableTable, MixinsSortableTable<TransactionsWidgetsCardsFinalized> {
  final TransactionCalculation _calc = TransactionCalculation();

  TransactionsController get txController => CoreLocator.getit<TransactionsController>();
  CryptosController get _cryptosController => CoreLocator.getit<CryptosController>();

  late String _resultSymbol;
  late List<TransactionsModel> txs;

  Decimal _capitalTotal = Decimal.zero;
  Decimal _capitalUsed = Decimal.zero;

  Map<int, Decimal> _finalizedBalance = {};

  bool _isOpen = true;

  @override
  String get sortableKey => "tx-group-finalized-${widget.id}";

  @override
  String get selectableKey => "tx-group-finalized-${widget.id}";

  @override
  void initState() {
    super.initState();

    txs = widget.transactions;

    _isOpen = widget.isOpen;
    _resultSymbol = _cryptosController.getSymbol(widget.id) ?? 'Unknown Coin';

    sortableSorters = {
      0: (col, asc) => sortableOnSort((d) => d['_timestamp'] as int, col, asc),
      1: (col, asc) => sortableOnSort((d) => d['_capitalUsed'] as double, col, asc),
    };

    _calculatePanelData();
    rows = _buildRows();
    sortableApplySorting(pauseRefresh: true);
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
      txs: [],
      selectedRows: [],
      isOpen: _isOpen,
      isDeletable: false,
      isClosable: false,
      isFinalizable: false,
      isRefundable: false,
      isUpdatable: false,
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
      value: 0,
      comparator: 0,
    );

    final capitalFinalized = TransactionsWidgetsPanelItem(
      title: "Finalized",
      subtitle: "${Utils.formatSmartDecimal(_capitalUsed)} $_resultSymbol",
      value: 0,
      comparator: 0,
    );

    final finalizedPanels = _finalizedBalance.entries.map((e) {
      final rrId = e.key;
      final total = e.value;
      final symbol = _cryptosController.getSymbol(rrId) ?? "UNK";

      return TransactionsWidgetsPanelItem(title: symbol, subtitle: Utils.formatSmartDecimal(total), value: 0, comparator: 0);
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
      WidgetsTableColumn(label: Text('Date'), fixedWidth: 100, onSort: sortableSorters[0]),
      WidgetsTableColumn(label: Text('Transaction'), size: ColumnSize.M),
      WidgetsTableColumn(label: Text('Exchanged Rate'), size: ColumnSize.M),
      WidgetsTableColumn(
        label: WidgetsHeader(title: 'Finalized Amount'),
        size: ColumnSize.S,
      ),
      WidgetsTableColumn(label: Text('Capital Used'), size: ColumnSize.M, onSort: sortableSorters[1]),
    ];
    final tableRows = rows.map((r) {
      final tx = r['tx'] as TransactionsModel;

      return DataRow2(
        key: ValueKey(r['uuid']),
        selected: selectableIsSelected(r['uuid']),
        onSelectChanged: (v) {
          selectableSetSelected(r['uuid'], v!);
          _calculatePanelData();
          sortableApplySorting();
        },
        onTap: () {
          TransactionsDialogsDetails.show(context, r['tx']);
        },
        cells: [
          DataCell(WidgetsWithTooltip(Text(r['date']), r['note'], tx.meta['accent_color'])),
          DataCell(Text(r['source'])),
          DataCell(Text(r['exchangedRate'])),
          DataCell(Text(r['balance'])),
          DataCell(Text(r['capitalUsed'])),
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

    for (final tx in txs) {
      final sourceCoinSymbol = _cryptosController.getSymbol(tx.srId);
      final resultCoinSymbol = _cryptosController.getSymbol(tx.rrId);
      final capitalUsed = _calc.totalCapitalUsed(tx, txController.items);

      rx.add({
        'balance': '${tx.balanceText} $resultCoinSymbol',
        'source': tx.isCapital ? 'Capital' : '${tx.srAmountText} $sourceCoinSymbol to ${tx.rrAmountText} $resultCoinSymbol',
        'exchangedRate': tx.isCapital ? ' - ' : '1 $sourceCoinSymbol = ${tx.rateText} $resultCoinSymbol',
        'date': tx.timestampAsFormattedDate,
        'tx': tx,
        'uuid': tx.uuid,
        'note': tx.noteText,
        'capitalUsed': "${Utils.formatSmartDecimal(capitalUsed)} $_resultSymbol",

        '_note': tx.noteText,
        '_timestamp': tx.sanitizedTimestamp,
        '_capitalUsed': capitalUsed.toDouble(),
      });
    }

    return rx;
  }

  void _calculatePanelData() {
    if (txs.isEmpty) {
      return;
    }

    final stxs = [...txs];

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
      used = Math.add(used, _calc.totalCapitalUsed(rtx, txController.items));
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
