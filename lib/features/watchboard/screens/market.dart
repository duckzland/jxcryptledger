import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/content.dart';
import '../../../core/locator.dart';
import '../../../core/scrollto.dart';
import '../../../mixins/action_bar.dart';
import '../../../mixins/scrollto_table.dart';
import '../../../mixins/sortable_table.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/header.dart';
import '../../../widgets/panel.dart';
import '../../../widgets/separator.dart';
import '../../../widgets/table/column.dart';
import '../markets/controller.dart';
import '../markets/mixins/filterable.dart';
import '../markets/model.dart';
import '../markets/widgets/notice.dart';

class WatchboardScreensMarket extends StatefulWidget {
  final Widget screenNavigation;
  const WatchboardScreensMarket({super.key, required this.screenNavigation});

  @override
  State<WatchboardScreensMarket> createState() => _WatchboardScreensMarketState();
}

class _WatchboardScreensMarketState extends State<WatchboardScreensMarket>
    with
        MixinsState,
        MixinsTable,
        MixinsSortableTable<WatchboardScreensMarket>,
        MixinsScrollToTable<WatchboardScreensMarket, MarketsModel>,
        MixinsActionBar<WatchboardScreensMarket>,
        WatchboardMarketsMixinsFilterable<WatchboardScreensMarket> {
  late List<MarketsModel> txs;
  MarketsController get _controller => CoreLocator.getit<MarketsController>();

  @override
  String get sortableKey => "px-group-market";

  @override
  final scrollToUtil = ScrollTo('px-group-offset-market');

  @override
  String get marketFilterableKey => "px-group-market";

  @override
  void initState() {
    super.initState();

    _controller.addListener(onMarketChange);

    sortableSorters = {
      0: (col, asc) => sortableOnSort((d) => (d['tx'] as MarketsModel).rank, col, asc),
      1: (col, asc) => sortableOnSort((d) => (d['tx'] as MarketsModel).symbol, col, asc),
      2: (col, asc) => sortableOnSort((d) => (d['tx'] as MarketsModel).price ?? 0, col, asc),
      3: (col, asc) => sortableOnSort((d) => (d['tx'] as MarketsModel).percent1h ?? 0, col, asc),
      4: (col, asc) => sortableOnSort((d) => (d['tx'] as MarketsModel).percent24h ?? 0, col, asc),
      5: (col, asc) => sortableOnSort((d) => (d['tx'] as MarketsModel).percent7d ?? 0, col, asc),
      6: (col, asc) => sortableOnSort((d) => (d['tx'] as MarketsModel).percent30d ?? 0, col, asc),
      7: (col, asc) => sortableOnSort((d) => (d['tx'] as MarketsModel).marketCap ?? 0, col, asc),
    };

    sortableAscending = states.get("[np]-$sortableKey-sortable-ascending", defaultValue: true);

    _processTxs();
  }

  @override
  void dispose() {
    scrollToUtil.dispose();
    _controller.removeListener(onMarketChange);
    super.dispose();
  }

  @override
  void marketFilterableOnPriceFiltering(int value) => onMarketChange();

  @override
  void marketFilterableOnPercentFiltering(int value) => onMarketChange();

  @override
  Widget actionbarLeftAction() {
    List<Widget> navigation = [widget.screenNavigation];
    if (_controller.isNotEmpty()) {
      navigation = [widget.screenNavigation, const WidgetsSeparator(), marketFilterableRankFilters()];
    }
    return Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: navigation);
  }

  @override
  Widget build(BuildContext context) {
    actionbarRegister("Crypto Market");

    if (_controller.isEmpty()) {
      return WatchboardsMarketsWidgetsNotice(callback: () => setState(() {}));
    }

    return AppContent(
      boxConstraints: BoxConstraints(maxWidth: 1600),
      padding: EdgeInsets.only(left: 16, right: 16, bottom: 12),
      children: [
        WidgetsPanel(
          child: DataTable2(
            key: Key("table-market"),
            scrollController: scrollToUtil.controller,
            minWidth: 1200,
            columnSpacing: 12,
            horizontalMargin: 12,
            headingRowHeight: tableHeadingHeight,
            dataRowHeight: tableRowHeight * 1.2,
            showCheckboxColumn: false,
            sortColumnIndex: sortableColumnIndex,
            sortAscending: sortableAscending,
            isHorizontalScrollBarVisible: false,
            empty: Center(
              child: Text("No market data available", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            columns: [
              WidgetsTableColumn(label: Text('#'), fixedWidth: 50, onSort: sortableSorters[0]),
              WidgetsTableColumn(label: Text('Name'), size: ColumnSize.L, onSort: sortableSorters[1]),
              WidgetsTableColumn(label: Text('Price'), size: ColumnSize.S, onSort: sortableSorters[2]),
              WidgetsTableColumn(label: Text('1h %'), size: ColumnSize.S, onSort: sortableSorters[3]),
              WidgetsTableColumn(label: Text('24h %'), size: ColumnSize.S, onSort: sortableSorters[4]),
              WidgetsTableColumn(label: Text('7d %'), size: ColumnSize.S, onSort: sortableSorters[5]),
              WidgetsTableColumn(label: Text('30d %'), size: ColumnSize.S, onSort: sortableSorters[6]),
              WidgetsTableColumn(label: Text('M.Cap'), fixedWidth: 100, onSort: sortableSorters[7]),
            ],
            rows: rows.map((r) {
              final MarketsModel tx = r['tx'];
              return DataRow2(
                key: ValueKey(tx.uuid),
                cells: [
                  DataCell(Text(tx.rankText)),
                  DataCell(
                    WidgetsHeader(
                      title: tx.name,
                      subtitle: tx.symbol,
                      spacing: 1,
                      reversed: true,
                      titleFontSize: 13,
                      titleFontWeight: FontWeight.w500,
                      subtitleFontSize: 10,
                    ),
                  ),
                  DataCell(Text(tx.priceText)),
                  DataCell(WidgetsBalanceText(text: tx.percent1hText, value: tx.percent1h?.toDouble() ?? 0, comparator: 0)),
                  DataCell(WidgetsBalanceText(text: tx.percent24hText, value: tx.percent24h?.toDouble() ?? 0, comparator: 0)),
                  DataCell(WidgetsBalanceText(text: tx.percent7dText, value: tx.percent7d?.toDouble() ?? 0, comparator: 0)),
                  DataCell(WidgetsBalanceText(text: tx.percent30dText, value: tx.percent30d?.toDouble() ?? 0, comparator: 0)),
                  DataCell(Text(tx.marketCapText)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _buildRows() {
    final rx = <Map<String, dynamic>>[];

    for (final m in txs) {
      rx.add({'tx': m});
    }
    return rx;
  }

  void onMarketChange() {
    setState(() {
      _processTxs();
    });
  }

  void _processTxs() {
    txs = [..._controller.items];
    txs = marketFilterableFilter(txs);
    rows = _buildRows();

    sortableApplySorting(pauseRefresh: true);
  }
}
