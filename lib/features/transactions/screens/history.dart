import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../widgets/panel.dart';
import '../model.dart';
import '../widgets/tree_card.dart';

class TransactionHistory extends StatefulWidget {
  final List<TransactionsModel> transactions;
  final int sortMode;

  const TransactionHistory({super.key, required this.transactions, required this.sortMode});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  late IndexedTreeNode<TransactionsModel> _root;
  late Map<String, IndexedTreeNode<TransactionsModel>> _nodes;
  late int _sortMode = widget.sortMode;

  @override
  void initState() {
    super.initState();
    _root = _buildTreeNodes(widget.transactions);
  }

  @override
  void didUpdateWidget(covariant TransactionHistory oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (oldWidget.transactions.isEmpty && widget.transactions.isNotEmpty) {
      _root = _buildTreeNodes(widget.transactions);
      setState(() {});
      return;
    }

    if (oldWidget.transactions.isNotEmpty && widget.transactions.isEmpty) {
      _root.clear();
      _nodes = {};
      setState(() {});
      return;
    }

    if (oldWidget.sortMode != widget.sortMode) {
      _sortMode = widget.sortMode;
      _root = _buildTreeNodes(widget.transactions);
      setState(() {});
      return;
    }

    if (oldWidget.transactions != widget.transactions) {
      updateTree(oldWidget.transactions, widget.transactions);
    }
  }

  void updateTree(List<TransactionsModel> oldTxs, List<TransactionsModel> newTxs) {
    final oldIds = oldTxs.map((t) => t.tid).toSet();
    final newIds = newTxs.map((t) => t.tid).toSet();

    final added = newIds.difference(oldIds);
    final removed = oldIds.difference(newIds);
    final updated = newIds.intersection(oldIds);

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

    for (final tid in added) {
      final tx = newTxs.firstWhere((t) => t.tid == tid);
      final node = IndexedTreeNode<TransactionsModel>(key: tx.tid, data: tx);
      final parent = tx.isRoot ? _root : _nodes[tx.pid];

      if (parent != null) {
        _nodes[tx.tid] = node;

        switch (_sortMode) {
          case 0:
            final children = parent.childrenAsList.cast<IndexedTreeNode<TransactionsModel>>();
            final idx = children.indexWhere((c) => c.data!.srId.compareTo(tx.srId) > 0);
            if (idx == -1) {
              parent.add(node);
            } else {
              parent.insert(idx, node);
            }
            break;

          case 1:
            parent.add(node);
            break;

          case 2:
            parent.insert(0, node);
            break;
        }
      }
    }

    for (final tid in updated) {
      final newTx = newTxs.firstWhere((t) => t.tid == tid);
      final node = _nodes[tid];
      if (node != null) {
        node.data = newTx;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: WidgetsPanel(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: TreeView.indexed(
            key: ValueKey(_sortMode),
            tree: _root,
            padding: const EdgeInsets.only(left: 16),
            showRootNode: false,
            indentation: const Indentation(style: IndentStyle.roundJoint),
            expansionBehavior: ExpansionBehavior.scrollToLastChild,
            animation: kAlwaysCompleteAnimation,

            expansionIndicatorBuilder: (context, node) => ChevronIndicator.rightDown(
              tree: node,
              color: AppTheme.text,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              alignment: Alignment.topRight,
            ),
            onTreeReady: (controller) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;

                for (final child in _root.childrenAsList) {
                  controller.expandAllChildren(child as IndexedTreeNode<TransactionsModel>, recursive: true);
                }
              });
            },
            builder: (context, node) {
              final tx = node.data;
              if (tx == null) return const SizedBox.shrink();
              return TransactionsTreeCard(key: ValueKey(tx.tid), tx: tx, node: node, onAction: () {});
            },
          ),
        ),
      ),
    );
  }

  IndexedTreeNode<TransactionsModel> _buildTreeNodes(List<TransactionsModel> txs) {
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
}
