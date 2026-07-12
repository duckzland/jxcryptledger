import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/scrollto.dart';
import '../../../mixins/scrollto_group.dart';
import '../../../mixins/state.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../mixins/flags.dart';
import '../widgets/cards/active.dart';
import '../model.dart';

class TransactionsActiveView extends StatefulWidget {
  final List<TransactionsModel> transactions;
  final Map<String, Map<TransactionsFlagsType, bool>> txsFlags;
  final int filterMode;
  final int sortMode;
  final VoidCallback onStatusChanged;
  final String panelsAction;

  const TransactionsActiveView({
    super.key,
    required this.transactions,
    required this.filterMode,
    required this.sortMode,
    required this.onStatusChanged,
    required this.panelsAction,
    required this.txsFlags,
  });

  @override
  State<TransactionsActiveView> createState() => _TransactionsActiveViewState();
}

class _TransactionsActiveViewState extends State<TransactionsActiveView>
    with MixinsState, MixinsScrollToGroup<TransactionsActiveView, TransactionsModel> {
  late final TransactionsController txController;
  late final CryptosController _cryptosController;
  late List<TransactionsModel> txs;

  Map<String, List<TransactionsModel>> groups = {};
  List<String> groupKeys = [];

  int _filterMode = 0;
  int _sortMode = 0;

  @override
  final scrollToUtil = ScrollTo('tx-group-offset-active');

  @override
  void initState() {
    super.initState();
    txController = locator<TransactionsController>();
    _cryptosController = locator<CryptosController>();

    txs = widget.transactions;

    _filterMode = widget.filterMode;
    _sortMode = widget.sortMode;

    groups = _processTx();
    groupKeys = groups.keys.toList();

    if (widget.panelsAction.isNotEmpty) {
      final open = widget.panelsAction == 'show' ? true : false;
      for (final key in groups.keys) {
        states.set("tx-group-active-open-$key", open);
      }
    }
  }

  @override
  void dispose() {
    scrollToUtil.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsActiveView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (widget.panelsAction.isNotEmpty && oldWidget.panelsAction != widget.panelsAction) {
      final open = widget.panelsAction == 'show' ? true : false;
      for (final key in groups.keys) {
        states.set("tx-group-active-open-$key", open);
      }
      setState(() {});
      return;
    }

    if (widget.filterMode != oldWidget.filterMode || widget.sortMode != oldWidget.sortMode) {
      setState(() {
        _filterMode = widget.filterMode;
        _sortMode = widget.sortMode;
        groups = _processTx();
        groupKeys = groups.keys.toList();
      });
      return;
    }

    if (!txController.isEqualToItems(txs)) {
      setState(() {
        final tx = txController.findNew(txs);
        txs = widget.transactions;

        String key = "";
        Map<String, List<TransactionsModel>> oldGroups = groups;

        groups = _processTx();
        groupKeys = groups.keys.toList();
        key = (tx != null) ? "${tx.srId}-${tx.rrId}" : scrollToGroupGetDifferenceKey(groups, oldGroups) ?? "";

        if (key != "") {
          states.set("tx-group-active-open-$key", true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollToGroup(key, groups, context);
          });
        }
      });
    }
  }

  @override
  double scrollToGroupGetGroupHeight(String id, List<TransactionsModel> txs, double currentWidth) {
    final isOpen = states.get("tx-group-active-open-$id", defaultValue: true);

    double height = 32.0;
    if (currentWidth > 1035) {
      height += 42;
    } else {
      height += 137;
    }

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
    if (groups.isEmpty) {
      return Center(
        child: Text(
          _filterMode == 0 ? "No active transactions available" : "No transactions available",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      );
    }

    final separator = EdgeInsets.only(bottom: scrollToGroupGetSeparatorHeight());
    final theme = Theme.of(context);

    return ListView.custom(
      controller: scrollToUtil.controller,
      scrollCacheExtent: const ScrollCacheExtent.viewport(2.0),
      itemExtentBuilder: (index, dimensions) {
        final key = groupKeys[index];
        return scrollToGroupGetGroupHeight(key, groups[key] ?? [], dimensions.crossAxisExtent) + scrollToGroupGetSeparatorHeight();
      },
      childrenDelegate: SliverChildBuilderDelegate(
        (BuildContext itemContext, int idx) {
          final key = groupKeys[idx];
          final parts = key.split('-');

          final srId = int.parse(parts[0]);
          final rrId = int.parse(parts[1]);
          final stxs = groups[key]!;

          return Padding(
            padding: separator,
            child: TransactionsWidgetsCardsActive(
              key: ValueKey("$srId-$rrId"),
              srid: srId,
              rrid: rrId,
              transactions: stxs,
              txsFlags: widget.txsFlags,
              onStatusChanged: widget.onStatusChanged,
              onToggleChanged: _toggleAction,
              parentContext: context,
              theme: theme,
              isOpen: states.get("tx-group-active-open-$key", defaultValue: true),
            ),
          );
        },
        childCount: groupKeys.length,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: false,
        findChildIndexCallback: (Key key) {
          if (key is ValueKey<String>) {
            final targetIdx = groupKeys.indexWhere((k) => k == key.value);
            if (targetIdx != -1) {
              return targetIdx;
            }
          }
          return null;
        },
      ),
    );
  }

  Map<String, List<TransactionsModel>> _processTx() {
    List<TransactionsModel> filtered;

    switch (_filterMode) {
      case 0:
        filtered = txs.where((t) => t.status == TransactionStatus.active.index || t.status == TransactionStatus.partial.index).toList();
        break;

      default:
        filtered = txs;
    }

    final grouped = <String, List<TransactionsModel>>{};
    for (final tx in filtered) {
      final pairKey = "${tx.srId}-${tx.rrId}";
      grouped.putIfAbsent(pairKey, () => []);
      grouped[pairKey]!.add(tx);
    }

    final entries = grouped.entries.toList();
    switch (_sortMode) {
      case 0:
        entries.sort((a, b) {
          final aParts = a.key.split('-');
          final bParts = b.key.split('-');

          final aSr = _cryptosController.getSymbol(int.parse(aParts[0])) ?? aParts[0];
          final bSr = _cryptosController.getSymbol(int.parse(bParts[0])) ?? bParts[0];
          return aSr.compareTo(bSr);
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

  void _toggleAction() {
    setState(() {});
  }
}
