import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/content.dart';
import '../../../app/exceptions.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/scrollto.dart';
import '../../../core/utils.dart';
import '../../../mixins/action_bar.dart';
import '../../../mixins/scrollto_table.dart';
import '../../../mixins/sortable_table.dart';
import '../../../mixins/state.dart';
import '../../../mixins/table.dart';
import '../../../widgets/balance_text.dart';
import '../../../widgets/header.dart';
import '../../../widgets/notify.dart';
import '../../../widgets/panel.dart';
import '../../../widgets/screens/notice.dart';
import '../../../widgets/table/column.dart';
import '../markets/controller.dart';
import '../markets/model.dart';

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
        MixinsActionBar<WatchboardScreensMarket> {
  late List<MarketsModel> txs;
  MarketsController get _controller => locator<MarketsController>();

  @override
  String get sortableKey => "px-group-market";

  @override
  final scrollToUtil = ScrollTo('px-group-offset-market');

  @override
  void initState() {
    super.initState();
    txs = [..._controller.items];

    _controller.addListener(onMarketChange);

    sortableSorters = {
      0: (col, asc) => sortableOnSort((d) => d['_rank'] as int, col, asc),
      1: (col, asc) => sortableOnSort((d) => d['name'] as String, col, asc),
      2: (col, asc) => sortableOnSort((d) => d['_price'] as double?, col, asc),
      3: (col, asc) => sortableOnSort((d) => d['_percent1h'] as double?, col, asc),
      4: (col, asc) => sortableOnSort((d) => d['_percent24h'] as double?, col, asc),
      5: (col, asc) => sortableOnSort((d) => d['_percent7d'] as double?, col, asc),
      6: (col, asc) => sortableOnSort((d) => d['_percent30d'] as double?, col, asc),
      7: (col, asc) => sortableOnSort((d) => d['_marketCap'] as double?, col, asc),
    };

    sortableAscending = states.get("[np]-$sortableKey-sortable-ascending", defaultValue: true);

    rows = _buildRows();

    sortableApplySorting(pauseRefresh: true);
  }

  @override
  void dispose() {
    scrollToUtil.dispose();
    _controller.removeListener(onMarketChange);
    super.dispose();
  }

  @override
  Widget actionbarLeftAction() {
    List<Widget> navigation = [widget.screenNavigation];
    return Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: navigation);
  }

  @override
  Widget build(BuildContext context) {
    actionbarRegister("Crypto Market");

    if (_controller.isEmpty()) {
      return WidgetsScreensNotice(
        title: "No market data available",
        btnTitle: "Download",
        btnTooltip: "Retrieve latest market data",
        btnEvaluator: (s) {
          _controller.isFetching ? s.progress() : s.action();
        },
        btnCallback: () async {
          try {
            await _controller.refreshRates();
            if (_controller.isNotEmpty()) {
              widgetsNotifySuccess("Successfully retrieved latest market data.");
            } else {
              widgetsNotifyError("Failed to retrieve market data. Please check your internet connection.");
            }
            setState(() {});
          } catch (e) {
            // This is pre IPC. Need new way!.
            if (e is NetworkingException) {
              widgetsNotifyError(e.userMessage);
            }
          }
        },
      );
    }

    return AppContent(
      boxConstraints: const BoxConstraints(maxWidth: 1600),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      spacing: 10,
      children: [
        WidgetsPanel(
          child: DataTable2(
            key: const Key("table-market"),
            scrollController: scrollToUtil.controller,
            minWidth: 1200,
            columnSpacing: 12,
            horizontalMargin: 12,
            headingRowHeight: tableHeadingHeight,
            dataRowHeight: tableRowHeight,
            showCheckboxColumn: false,
            sortColumnIndex: sortableColumnIndex,
            sortAscending: sortableAscending,
            isHorizontalScrollBarVisible: false,
            empty: const Center(
              child: Text("No market data available", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            columns: [
              WidgetsTableColumn(label: const Text('#'), fixedWidth: 40, onSort: sortableSorters[0]),
              WidgetsTableColumn(label: const Text('Name'), size: ColumnSize.L, onSort: sortableSorters[1]),
              WidgetsTableColumn(label: const Text('Price'), size: ColumnSize.M, onSort: sortableSorters[2]),
              WidgetsTableColumn(label: const Text('1h %'), size: ColumnSize.S, onSort: sortableSorters[3]),
              WidgetsTableColumn(label: const Text('24h %'), size: ColumnSize.S, onSort: sortableSorters[4]),
              WidgetsTableColumn(label: const Text('7d %'), size: ColumnSize.S, onSort: sortableSorters[5]),
              WidgetsTableColumn(label: const Text('30d %'), size: ColumnSize.S, onSort: sortableSorters[6]),
              WidgetsTableColumn(label: const Text('M.Cap'), size: ColumnSize.S, onSort: sortableSorters[7]),
            ],
            rows: rows.map((r) {
              return DataRow2(
                key: ValueKey(r['uuid']),
                cells: [
                  DataCell(Text(r['rank'])),
                  DataCell(WidgetsHeader(title: r['name'], subtitle: r['symbol'], byside: true, spacing: 5)),
                  DataCell(Text(r['price'])),
                  DataCell(WidgetsBalanceText(text: r['percent1h'], value: r['_percent1h'] ?? 0, comparator: 0)),
                  DataCell(WidgetsBalanceText(text: r['percent24h'], value: r['_percent24h'] ?? 0, comparator: 0)),
                  DataCell(WidgetsBalanceText(text: r['percent7d'], value: r['_percent7d'] ?? 0, comparator: 0)),
                  DataCell(WidgetsBalanceText(text: r['percent30d'], value: r['_percent30d'] ?? 0, comparator: 0)),
                  DataCell(Text(r['marketCap'])),
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
      rx.add({
        'uuid': m.uuid,

        'name': m.name,
        'symbol': m.symbol,
        'rank': m.rank.toString(),
        'price': Utils.formatSmartDouble(m.price ?? 0),
        'percent1h': Utils.formatSmartDouble(m.percent1h ?? 0, maxDecimals: 2, smartDecimal: false),
        'percent24h': Utils.formatSmartDouble(m.percent24h ?? 0, maxDecimals: 2, smartDecimal: false),
        'percent7d': Utils.formatSmartDouble(m.percent7d ?? 0, maxDecimals: 2, smartDecimal: false),
        'percent30d': Utils.formatSmartDouble(m.percent30d ?? 0, maxDecimals: 2, smartDecimal: false),
        'marketCap': Utils.formatShortCurrency(m.marketCap ?? 0),

        '_rank': m.rank,
        '_price': m.price,
        '_percent1h': m.percent1h,
        '_percent24h': m.percent24h,
        '_percent7d': m.percent7d,
        '_percent30d': m.percent30d,
        '_marketCap': m.marketCap,
      });
    }
    return rx;
  }

  void onMarketChange() {
    setState(() {
      txs = [..._controller.items];
      rows = _buildRows();

      sortableApplySorting(pauseRefresh: true);
    });
  }
}
