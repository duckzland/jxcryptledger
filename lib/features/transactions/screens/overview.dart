import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/scrollto.dart';
import '../../../mixins/scrollto_group.dart';
import '../../../mixins/state.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../model.dart';
import '../widgets/overview_card.dart';

class TransactionsOverviewView extends StatefulWidget {
  final List<TransactionsModel> transactions;
  final int filterMode;
  final int sortMode;
  final VoidCallback onStatusChanged;
  final String panelsAction;

  const TransactionsOverviewView({
    super.key,
    required this.transactions,
    required this.filterMode,
    required this.sortMode,
    required this.onStatusChanged,
    required this.panelsAction,
  });

  @override
  State<TransactionsOverviewView> createState() => _TransactionsOverviewViewState();
}

class _TransactionsOverviewViewState extends State<TransactionsOverviewView>
    with AutomaticKeepAliveClientMixin, MixinsState, MixinsScrollToGroup<TransactionsOverviewView, TransactionsModel> {
  TransactionsController get _txController => locator<TransactionsController>();
  CryptosController get _cryptosController => locator<CryptosController>();

  late List<TransactionsModel> txs;

  Map<String, List<TransactionsModel>> groups = {};
  int _filterMode = 0;
  int _sortMode = 0;

  @override
  final scrollToUtil = ScrollTo('tx-group-offset-overview');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    txs = widget.transactions;
    _filterMode = widget.filterMode;
    _sortMode = widget.sortMode;
    groups = _processTx();

    if (widget.panelsAction.isNotEmpty) {
      final open = widget.panelsAction == 'show' ? true : false;
      for (final key in groups.keys) {
        states.set("tx-group-overview-open-$key", open);
      }
    }
  }

  @override
  void dispose() {
    scrollToUtil.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsOverviewView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (widget.panelsAction.isNotEmpty && oldWidget.panelsAction != widget.panelsAction) {
      final open = widget.panelsAction == 'show' ? true : false;
      for (final key in groups.keys) {
        states.set("tx-group-overview-open-$key", open);
      }
      setState(() {});
      return;
    }

    if (widget.filterMode != oldWidget.filterMode || widget.sortMode != oldWidget.sortMode) {
      setState(() {
        _filterMode = widget.filterMode;
        _sortMode = widget.sortMode;
        groups = _processTx();
      });
      return;
    }

    if (!_txController.isEqualToItems(txs)) {
      setState(() {
        final tx = _txController.findNew(txs);
        txs = widget.transactions;

        String key = "";
        Map<String, List<TransactionsModel>> oldGroups = groups;

        groups = _processTx();
        key = (tx != null) ? tx.rrId.toString() : scrollToGroupGetDifferenceKey(groups, oldGroups) ?? "";

        if (key != "") {
          states.set("tx-group-overview-open-$key", true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollToGroup(key, groups, context);
          });
        }
      });
    }
  }

  @override
  double scrollToGroupGetGroupHeight(String id, List<TransactionsModel> txs, double currentWidth) {
    final isOpen = states.get("tx-group-overview-open-$id", defaultValue: true);

    double height = 0.0;

    height += 16 + 16;
    height += (currentWidth > 560) ? 40 : 90;

    if (isOpen) {
      height += 20;
      height += (txs.length * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12;
    }

    return height;
  }

  @override
  double scrollToGroupGetSeparatorHeight() {
    return 24;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return groups.isEmpty
        ? Center(
            child: Text(
              _filterMode == 0 ? "No active transactions available" : "No transactions available",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          )
        : ListView.separated(
            controller: scrollToUtil.controller,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 24),
            itemBuilder: (itemContext, idx) {
              final rrId = groups.keys.elementAt(idx);
              final stxs = groups[rrId]!;

              return TransactionsOverviewCard(
                key: ValueKey("card-$rrId"),
                id: int.parse(rrId),
                transactions: stxs,
                onStatusChanged: widget.onStatusChanged,
                parentContext: context,
                isOpen: states.get("tx-group-overview-open-$rrId", defaultValue: true),
              );
            },
          );
  }

  Map<String, List<TransactionsModel>> _processTx() {
    List<TransactionsModel> filtered;

    switch (_filterMode) {
      case 0:
        filtered = txs.where((t) => t.status == 1 || t.status == 2).toList();
        break;

      default:
        filtered = txs.toList();
    }

    final grouped = <String, List<TransactionsModel>>{};
    for (final tx in filtered) {
      grouped.putIfAbsent(tx.rrId.toString(), () => <TransactionsModel>[]);
      grouped[tx.rrId.toString()]!.add(tx);
    }

    final entries = grouped.entries.toList();

    switch (_sortMode) {
      case 0:
        entries.sort((a, b) {
          final symbolA = _cryptosController.getSymbol(int.parse(a.key)) ?? a.key;
          final symbolB = _cryptosController.getSymbol(int.parse(b.key)) ?? b.key;
          return symbolA.compareTo(symbolB);
        });
        break;

      case 1:
        entries.sort((a, b) {
          final aDate = a.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x < y ? x : y);
          final bDate = b.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x < y ? x : y);
          return aDate.compareTo(bDate);
        });
        break;

      case 2:
        entries.sort((a, b) {
          final aDate = a.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x > y ? x : y);
          final bDate = b.value.map((tx) => tx.sanitizedTimestamp).reduce((x, y) => x > y ? x : y);
          return bDate.compareTo(aDate);
        });
        break;
    }

    return Map<String, List<TransactionsModel>>.fromEntries(entries);
  }
}
