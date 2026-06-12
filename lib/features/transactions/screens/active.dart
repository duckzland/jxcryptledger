import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/scrollto.dart';
import '../../../mixins/scrollto_group.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../widgets/active_card.dart';
import '../model.dart';

class TransactionsActiveView extends StatefulWidget {
  final List<TransactionsModel> transactions;
  final int filterMode;
  final int sortMode;
  final VoidCallback onStatusChanged;

  const TransactionsActiveView({
    super.key,
    required this.transactions,
    required this.filterMode,
    required this.sortMode,
    required this.onStatusChanged,
  });

  @override
  State<TransactionsActiveView> createState() => _TransactionsActiveViewState();
}

class _TransactionsActiveViewState extends State<TransactionsActiveView>
    with AutomaticKeepAliveClientMixin, MixinsScrollToGroup<TransactionsActiveView, TransactionsModel> {
  late final TransactionsController _txController;
  late final CryptosController _cryptosController;
  late List<TransactionsModel> txs;

  Map<String, List<TransactionsModel>> groups = {};
  int _filterMode = 0;
  int _sortMode = 0;

  @override
  final scrollToUtil = ScrollTo('tx-offset-active');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _txController = locator<TransactionsController>();
    _cryptosController = locator<CryptosController>();

    txs = widget.transactions;
    _filterMode = widget.filterMode;
    _sortMode = widget.sortMode;
    groups = _processTx();
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
        key = (tx != null) ? "${tx.srId}-${tx.rrId}" : scrollToGroupGetDifferenceKey(groups, oldGroups) ?? "";

        if (key != "") {
          scrollToGroup(key, groups, context);
        }
      });
    }
  }

  @override
  double scrollToGroupGetGroupHeight(List<TransactionsModel> txs, double currentWidth) {
    double height = 0.0;

    height += 16 + 20 + 16;
    height += (currentWidth > 1000) ? 40 : 120;

    height += (txs.length * AppTheme.tableDataRowMinHeight) + AppTheme.tableHeadingRowHeight + 12;

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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          )
        : ListView.separated(
            controller: scrollToUtil.controller,
            padding: EdgeInsets.only(bottom: 24),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 24),
            itemBuilder: (itemContext, idx) {
              final key = groups.keys.elementAt(idx);
              final parts = key.split('-');

              final srId = int.parse(parts[0]);
              final rrId = int.parse(parts[1]);

              final stxs = groups[key]!;

              return TransactionsActiveCard(
                srid: srId,
                rrid: rrId,
                transactions: stxs,
                onStatusChanged: widget.onStatusChanged,
                parentContext: context,
              );
            },
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
}
