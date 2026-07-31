import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../../app/content.dart';
import '../../../app/exceptions.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/scrollto.dart';
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
import '../../../widgets/separator.dart';
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

  int _filterMode = 0;

  @override
  String get sortableKey => "px-group-market";

  @override
  final scrollToUtil = ScrollTo('px-group-offset-market');

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

    _filterMode = states.get('px-group-filter-market', defaultValue: 0);

    _processTxs();
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
    if (_controller.isNotEmpty()) {
      navigation = [
        widget.screenNavigation,
        const WidgetsSeparator(),
        DropdownMenu<int>(
          initialSelection: _filterMode,
          alignmentOffset: const Offset(0, 3),
          requestFocusOnTap: false,
          inputDecorationTheme: Theme.of(
            context,
          ).inputDecorationTheme.copyWith(isDense: true, constraints: const BoxConstraints(maxHeight: 38)),
          showTrailingIcon: false,
          dropdownMenuEntries: [
            const DropdownMenuEntry<int>(value: 0, label: "Show All"),
            const DropdownMenuEntry<int>(value: 1, label: "Top 50"),
            const DropdownMenuEntry<int>(value: 2, label: "Top 100"),
            const DropdownMenuEntry<int>(value: 3, label: "Top 200"),
          ],
          onSelected: (value) {
            if (value == null) return;
            setState(() {
              _filterMode = value;
              _processTxs();
            });
            states.set('px-group-filter-market', value);
          },
        ),
      ];
    }
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
            dataRowHeight: tableRowHeight * 1.2,
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
              WidgetsTableColumn(label: const Text('Price'), size: ColumnSize.S, onSort: sortableSorters[2]),
              WidgetsTableColumn(label: const Text('1h %'), size: ColumnSize.S, onSort: sortableSorters[3]),
              WidgetsTableColumn(label: const Text('24h %'), size: ColumnSize.S, onSort: sortableSorters[4]),
              WidgetsTableColumn(label: const Text('7d %'), size: ColumnSize.S, onSort: sortableSorters[5]),
              WidgetsTableColumn(label: const Text('30d %'), size: ColumnSize.S, onSort: sortableSorters[6]),
              WidgetsTableColumn(label: const Text('M.Cap'), size: ColumnSize.S, onSort: sortableSorters[7]),
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
                  DataCell(WidgetsBalanceText(text: tx.percent1hText, value: tx.percent1h ?? 0, comparator: 0)),
                  DataCell(WidgetsBalanceText(text: tx.percent24hText, value: tx.percent24h ?? 0, comparator: 0)),
                  DataCell(WidgetsBalanceText(text: tx.percent7dText, value: tx.percent7d ?? 0, comparator: 0)),
                  DataCell(WidgetsBalanceText(text: tx.percent30dText, value: tx.percent30d ?? 0, comparator: 0)),
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

    switch (_filterMode) {
      case 1:
        txs = txs.where((tx) => tx.rank >= 1 && tx.rank <= 50).toList();
        break;

      case 2:
        txs = txs.where((tx) => tx.rank >= 1 && tx.rank <= 100).toList();
        break;

      case 3:
        txs = txs.where((tx) => tx.rank >= 101 && tx.rank <= 200).toList();
        break;

      default:
        break;
    }

    rows = _buildRows();

    sortableApplySorting(pauseRefresh: true);
  }
}
