import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../mixins/state.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../mixins/flags.dart';
import '../widgets/tree_card.dart';
import '../controller.dart';
import '../model.dart';

class TransactionHistory extends StatefulWidget {
  final List<TransactionsModel> transactions;
  final int sortMode;
  final VoidCallback onStatusChanged;
  final String panelsAction;
  final Map<String, Map<String, bool>> txsFlags;

  const TransactionHistory({
    super.key,
    required this.transactions,
    required this.sortMode,
    required this.onStatusChanged,
    required this.panelsAction,
    required this.txsFlags,
  });

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> with MixinsState, TransactionsMixinsFlags {
  CryptosController get _cryptosController => locator<CryptosController>();

  late IndexedTreeNode<TransactionsModel> _root;
  late Map<String, IndexedTreeNode<TransactionsModel>> _nodes;
  late int _sortMode;
  TreeViewController<TransactionsModel, IndexedTreeNode<TransactionsModel>>? scrollController;
  late AutoScrollController _autoScrollController;

  @override
  void initState() {
    super.initState();
    txController = locator<TransactionsController>();

    _sortMode = widget.sortMode;
    txs = widget.transactions;
    txsFlags = widget.txsFlags;
    txs = _processTx();

    _root = _treeBuildNodes(txs);
    _autoScrollController = AutoScrollController(axis: Axis.vertical);
  }

  @override
  void dispose() {
    _autoScrollController.removeListener(_saveOffset);
    _autoScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TransactionHistory oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (widget.panelsAction.isNotEmpty && oldWidget.panelsAction != widget.panelsAction) {
      if (widget.panelsAction == "show") {
        for (final child in _root.childrenAsList) {
          scrollController?.expandAllChildren(child as IndexedTreeNode<TransactionsModel>, recursive: true);
        }
      }
      if (widget.panelsAction == "close") {
        for (final child in _root.childrenAsList) {
          scrollController?.collapseNode(child as IndexedTreeNode<TransactionsModel>);
        }
      }
      return;
    }

    _sortMode = widget.sortMode;
    txs = widget.transactions;
    txsFlags = widget.txsFlags;
    txs = _processTx();

    if (oldWidget.sortMode != widget.sortMode) {
      _root = _treeBuildNodes(txs);
      setState(() {});
      return;
    }

    if (txController.isBothEqualGroup(oldWidget.transactions, widget.transactions)) {
      return;
    }

    if (oldWidget.transactions.isEmpty && widget.transactions.isNotEmpty) {
      _root = _treeBuildNodes(txs);
      setState(() {});
      return;
    }

    if (oldWidget.transactions.isNotEmpty && widget.transactions.isEmpty) {
      _root.clear();
      _nodes = {};
      setState(() {});
      return;
    }

    setState(() {});

    _treeRemoveTxs(oldWidget.transactions, widget.transactions);
    _treeAddTxs(oldWidget.transactions, widget.transactions);
    _treeUpdateTxs(oldWidget.transactions, widget.transactions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: WidgetsPanel(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: TreeView.indexed(
            key: PageStorageKey('tree-history-$_sortMode'),
            tree: _root,
            padding: const EdgeInsets.only(left: 16),
            showRootNode: false,
            indentation: const Indentation(style: IndentStyle.roundJoint),
            expansionBehavior: ExpansionBehavior.scrollToLastChild,
            animation: kAlwaysCompleteAnimation,
            scrollController: _autoScrollController,
            expansionIndicatorBuilder: (context, node) => ChevronIndicator.rightDown(
              tree: node,
              color: AppTheme.text,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              alignment: Alignment.topRight,
            ),
            onTreeReady: (controller) {
              scrollController = controller;
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;

                for (final child in _root.childrenAsList) {
                  controller.expandAllChildren(child as IndexedTreeNode<TransactionsModel>, recursive: true);
                }

                // Must be done this way, impossible to use initialOffset.
                final initalOffset = states.get('tx-group-offset-history', defaultValue: 0.0);
                if (initalOffset != 0.0) {
                  _autoScrollController.jumpTo(initalOffset);
                }

                // AddListener late to prevent corrupting stored data.
                _autoScrollController.addListener(_saveOffset);
              });
            },
            builder: (context, node) {
              final tx = node.data;
              if (tx == null) return const SizedBox.shrink();
              return TransactionsTreeCard(
                key: ValueKey(tx.tid),
                tx: tx,
                node: node,
                isTradable: txFlagPick(tx, "tradable"),
                isClosable: txFlagPick(tx, "closable"),
                isDeletable: txFlagPick(tx, "deletable"),
                isUpdatable: txFlagPick(tx, "updatable"),
                isRefundable: txFlagPick(tx, "refundable"),
                isFinalizable: txFlagPick(tx, "finalizable"),
                hasLeaf: txFlagPick(tx, "hasLeaf"),
                hasTradeableLeaf: txFlagPick(tx, "hasTradeableLeaf"),
                onAction: widget.onStatusChanged,
              );
            },
          ),
        ),
      ),
    );
  }

  void _saveOffset() {
    states.set('tx-group-offset-history', _autoScrollController.offset);
  }

  void _treeRemoveTxs(List<TransactionsModel> oldTxs, List<TransactionsModel> newTxs) {
    final oldIds = oldTxs.map((t) => t.tid).toSet();
    final newIds = newTxs.map((t) => t.tid).toSet();
    final removed = oldIds.difference(newIds);

    for (final tid in removed) {
      final node = _nodes[tid];
      final tx = node?.data;
      if (tx != null) {
        if (tx.isRoot) {
          _root.remove(node!);
        } else {
          final px = _nodes[tx.pid];
          if (px != null) {
            px.remove(node!);
          }
        }

        _nodes.remove(tid);
      }
    }
  }

  void _treeAddTxs(List<TransactionsModel> oldTxs, List<TransactionsModel> newTxs) {
    final oldIds = oldTxs.map((t) => t.tid).toSet();
    final newIds = newTxs.map((t) => t.tid).toSet();
    final added = newIds.difference(oldIds);

    for (final tid in added) {
      final tx = newTxs.firstWhere((t) => t.tid == tid);
      final node = IndexedTreeNode<TransactionsModel>(key: tx.tid, data: tx);
      final parent = tx.isRoot ? _root : _nodes[tx.pid];

      if (parent == null) {
        continue;
      }

      _nodes[tx.tid] = node;

      final children = parent.childrenAsList.cast<IndexedTreeNode<TransactionsModel>>();
      if (children.isEmpty) {
        parent.add(node);
        continue;
      }

      switch (_sortMode) {
        case 0:
          final siblings = newTxs.where((c) => c.pid == tx.pid).toList();
          siblings.sort((a, b) {
            final aF = (_cryptosController.getSymbol(a.srId) ?? a.srId.toString()).trim().toLowerCase().characters.first;
            final bF = (_cryptosController.getSymbol(b.srId) ?? b.srId.toString()).trim().toLowerCase().characters.first;

            return aF.compareTo(bF);
          });

          final index = siblings.indexWhere((c) => c.tid == tx.tid);

          if (index == 0 || index == children.length) {
            parent.insert(index, node);
          } else {
            final tindex = index - 1;
            if (children.length > tindex) {
              final tdx = children[tindex];
              // Insert before is actually insert at and move the tdx down!
              parent.insertBefore(tdx, node);
            }
          }
          break;

        case 1:
          parent.add(node);
          break;

        case 2:
          parent.insert(0, node);
          break;
      }

      // This tree package is buggy, "Root" wont got scrolled when added while "leaves" does.
      if (tx.isRoot) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollController?.scrollToItem(node);
        });
      }
    }
  }

  void _treeUpdateTxs(List<TransactionsModel> oldTxs, List<TransactionsModel> newTxs) {
    final oldIds = oldTxs.map((t) => t.tid).toSet();
    final newIds = newTxs.map((t) => t.tid).toSet();
    final updated = newIds.intersection(oldIds);

    for (final tid in updated) {
      final tx = newTxs.firstWhere((t) => t.tid == tid);
      final node = _nodes[tid];
      final parent = tx.isRoot ? _root : _nodes[tx.pid];

      if (node == null || parent == null || txController.isBothEqual(tx, node.data!)) {
        continue;
      }

      final oldTx = node.data!;

      // Refreshing data
      node.data = tx;
      _nodes[tid] = node;

      // Attempting to reorder if possible
      final siblings = parent.childrenAsList.cast<IndexedTreeNode<TransactionsModel>>();
      final oldIndex = siblings.indexWhere((node) => node.data!.tid == tx.tid);

      if ((siblings.length == 1 && parent.indexWhere((c) => c == node) == 0) ||
          (oldTx.srId == tx.srId && _sortMode == 0) ||
          (oldTx.timestamp == tx.timestamp && (_sortMode == 1 || _sortMode == 2))) {
        continue;
      }

      switch (_sortMode) {
        case 0:
          siblings.sort((a, b) {
            final aF = (_cryptosController.getSymbol(a.data!.srId) ?? a.data!.srId.toString()).trim().toLowerCase().characters.first;
            final bF = (_cryptosController.getSymbol(b.data!.srId) ?? b.data!.srId.toString()).trim().toLowerCase().characters.first;

            return aF.compareTo(bF);
          });
          break;

        case 1:
          siblings.sort((a, b) => a.data!.sanitizedTimestamp.compareTo(b.data!.sanitizedTimestamp));
          break;
        case 2:
          siblings.sort((a, b) => b.data!.sanitizedTimestamp.compareTo(a.data!.sanitizedTimestamp));
          break;
      }

      final newIndex = siblings.indexWhere((node) => node.data!.tid == tx.tid);

      if (oldIndex != newIndex) {
        parent.remove(node);
        parent.insert(newIndex, node);

        if (oldTx.isRoot) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollController?.scrollToItem(node);
          });
        }
      }
    }
  }

  IndexedTreeNode<TransactionsModel> _treeBuildNodes(List<TransactionsModel> txs) {
    final root = IndexedTreeNode<TransactionsModel>.root();
    _nodes = <String, IndexedTreeNode<TransactionsModel>>{};

    for (final tx in txs) {
      _nodes[tx.tid] = IndexedTreeNode<TransactionsModel>(key: tx.tid, data: tx);
    }

    for (final tx in txs) {
      final currentNode = _nodes[tx.tid.toString()]!;
      if (tx.isRoot) {
        root.add(currentNode);
      } else {
        final parentNode = _nodes[tx.pid];
        parentNode?.add(currentNode);
      }
    }

    return root;
  }

  List<TransactionsModel> _processTx() {
    switch (_sortMode) {
      case 0:
        return List<TransactionsModel>.from(txs)..sort((a, b) {
          final aSr = _cryptosController.getSymbol(a.srId) ?? a.srId.toString();
          final bSr = _cryptosController.getSymbol(b.srId) ?? b.srId.toString();
          return aSr.compareTo(bSr);
        });

      case 1:
        return List<TransactionsModel>.from(txs)..sort((a, b) => a.sanitizedTimestamp.compareTo(b.sanitizedTimestamp));

      default:
        return List<TransactionsModel>.from(txs)..sort((a, b) => b.sanitizedTimestamp.compareTo(a.sanitizedTimestamp));
    }
  }
}
