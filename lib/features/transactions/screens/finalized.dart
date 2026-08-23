import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/scrollto.dart';
import '../../../mixins/rateable.dart';
import '../../../mixins/scrollto_group.dart';
import '../../../mixins/state.dart';
import '../mixins/flags.dart';
import '../widgets/balance_bar.dart';
import '../widgets/cards/finalized.dart';
import '../controller.dart';
import '../model.dart';

class TransactionsFinalizedView extends StatefulWidget {
  final List<TransactionsModel> transactions;
  final Map<String, Map<TransactionsFlagsType, bool>> txsFlags;
  final VoidCallback onStatusChanged;
  final String panelsAction;

  const TransactionsFinalizedView({
    super.key,
    required this.transactions,
    required this.onStatusChanged,
    required this.panelsAction,
    required this.txsFlags,
  });

  @override
  State<TransactionsFinalizedView> createState() => _TransactionsFinalizedViewState();
}

class _TransactionsFinalizedViewState extends State<TransactionsFinalizedView>
    with MixinsState, MixinsRateable<TransactionsFinalizedView>, MixinsScrollToGroup<TransactionsFinalizedView, TransactionsModel> {
  TransactionsController get txController => CoreLocator.getit<TransactionsController>();

  late List<TransactionsModel> txs;
  late ValueNotifier<List<String>> selectableGroup;

  Map<String, List<TransactionsModel>> groups = {};
  List<String> groupKeys = [];

  @override
  final scrollToUtil = ScrollTo('tx-group-offset-finalized');

  @override
  void initState() {
    super.initState();

    txs = widget.transactions;
    selectableGroup = ValueNotifier(states.get("tx-finalized-selectable-group", defaultValue: <String>[]));
    selectableGroup.addListener(_selectableGroupOnChange);

    groups = _processTx();
    groupKeys = groups.keys.toList();

    if (widget.panelsAction.isNotEmpty) {
      final open = widget.panelsAction == 'show' ? true : false;
      for (final key in groups.keys) {
        states.set("tx-group-finalized-open-$key", open);
      }
    }
  }

  @override
  void dispose() {
    selectableGroup.removeListener(_selectableGroupOnChange);
    selectableGroup.dispose();
    scrollToUtil.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionsFinalizedView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (widget.panelsAction.isNotEmpty && oldWidget.panelsAction != widget.panelsAction) {
      final open = widget.panelsAction == 'show' ? true : false;
      for (final key in groups.keys) {
        states.set("tx-group-finalized-open-$key", open);
      }
      setState(() {});
      return;
    }

    if (!txController.isEqualToItems(oldWidget.transactions)) {
      setState(() {
        final tx = txController.findNew(txs);
        txs = widget.transactions;

        String key = "";
        Map<String, List<TransactionsModel>> oldGroups = groups;

        groups = _processTx();
        groupKeys = groups.keys.toList();
        key = (tx != null) ? tx.rrId.toString() : scrollToGroupGetDifferenceKey(groups, oldGroups) ?? "";

        if (key != "") {
          states.set("tx-group-finalized-open-$key", true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollToGroup(key, groups, context);
          });
        }
      });
    }
  }

  @override
  double scrollToGroupGetGroupHeight(String id, List<TransactionsModel> txs, double currentWidth) {
    final isOpen = states.get("tx-group-finalized-open-$id", defaultValue: true);

    double height = 0.0;

    height += 16 + 16;
    height += (currentWidth > 595) ? 44 : 92;

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
        child: Text("No finalized transactions available", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      );
    }

    final separator = EdgeInsets.only(bottom: scrollToGroupGetSeparatorHeight());
    final theme = Theme.of(context);

    return Stack(
      children: [
        ListView.custom(
          controller: scrollToUtil.controller,
          scrollCacheExtent: const ScrollCacheExtent.viewport(2.0),
          itemExtentBuilder: (index, dimensions) {
            final key = groupKeys[index];
            return scrollToGroupGetGroupHeight(key, groups[key] ?? [], dimensions.crossAxisExtent) + scrollToGroupGetSeparatorHeight();
          },
          childrenDelegate: SliverChildBuilderDelegate(
            (BuildContext itemContext, int idx) {
              final rrId = groupKeys[idx];
              final stxs = groups[rrId]!;

              return Padding(
                padding: separator,
                child: TransactionsWidgetsCardsFinalized(
                  key: ValueKey(rrId),
                  id: int.parse(rrId),
                  transactions: stxs,
                  txsFlags: widget.txsFlags,
                  onStatusChanged: widget.onStatusChanged,
                  onToggleChanged: _toggleAction,
                  parentContext: context,
                  theme: theme,
                  isOpen: states.get("tx-group-finalized-open-$rrId", defaultValue: true),
                  scrollController: scrollToUtil.controller,
                  selectableGroup: selectableGroup,
                ),
              );
            },
            childCount: groupKeys.length,
            addAutomaticKeepAlives: true,
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
        ),
        TransactionsWidgetsBalanceBar(key: ValueKey("tx-finalized-balance-bar"), data: selectableGroup),
      ],
    );
  }

  Map<String, List<TransactionsModel>> _processTx() {
    List<TransactionsModel> filtered = txs.where((t) => t.isFinalized).toList();

    final grouped = <String, List<TransactionsModel>>{};
    for (final tx in filtered) {
      final TransactionsModel? px = tx.isRoot ? tx : txController.getRoot(tx);

      if (px == null) {
        continue;
      }

      grouped.putIfAbsent(px.srId.toString(), () => <TransactionsModel>[]);
      grouped[px.srId.toString()]!.add(tx);
    }

    final entries = grouped.entries.toList();
    return Map<String, List<TransactionsModel>>.fromEntries(entries);
  }

  void _toggleAction() {
    setState(() {});
  }

  void _selectableGroupOnChange() {
    states.set("tx-finalized-selectable-group", selectableGroup.value);
  }
}
