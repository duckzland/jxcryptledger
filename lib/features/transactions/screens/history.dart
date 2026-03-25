import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../widgets/panel.dart';
import '../model.dart';
import '../widgets/tree_card.dart';

class TransactionHistory extends StatefulWidget {
  final List<TransactionsModel> transactions;

  const TransactionHistory({super.key, required this.transactions});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  late TreeNode<TransactionsModel> _root;

  @override
  void initState() {
    super.initState();
    _root = _buildTreeNodes(widget.transactions);
  }

  @override
  void didUpdateWidget(covariant TransactionHistory oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.transactions != widget.transactions && mounted) {
      setState(() {
        _root = _buildTreeNodes(widget.transactions);
      });
    }
  }

  void refreshTree() {
    setState(() {
      _root = _buildTreeNodes(widget.transactions);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: WidgetsPanel(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: TreeView.simple(
            key: ValueKey(widget.transactions.map((e) => "${e.tid}-${e.timestamp}").join('|')),
            tree: _root,
            padding: const EdgeInsets.only(left: 16),
            showRootNode: false,
            indentation: const Indentation(style: IndentStyle.roundJoint),
            expansionBehavior: ExpansionBehavior.scrollToLastChild,
            expansionIndicatorBuilder: (context, node) => ChevronIndicator.rightDown(
              tree: node,
              color: AppTheme.text,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              alignment: Alignment.topRight,
            ),
            onTreeReady: (controller) {
              for (final child in _root.children.values) {
                controller.expandAllChildren(child as TreeNode<TransactionsModel>, recursive: true);
              }
            },
            builder: (context, node) {
              final tx = node.data;
              if (tx == null) return const SizedBox.shrink();
              return TransactionsTreeCard(
                tx: tx,
                node: node,
                onAction: () {
                  refreshTree();
                  if (mounted) {
                    setState(() {
                      _root = _buildTreeNodes(widget.transactions);
                    });
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  TreeNode<TransactionsModel> _buildTreeNodes(List<TransactionsModel> txs) {
    final root = TreeNode<TransactionsModel>.root();
    final nodes = <String, TreeNode<TransactionsModel>>{};

    int i = 0;
    for (final tx in txs) {
      nodes[tx.tid.toString()] = TreeNode<TransactionsModel>(key: "${tx.tid}-${tx.timestamp}-$i", data: tx);
      i++;
    }

    for (final tx in txs) {
      final currentNode = nodes[tx.tid.toString()]!;
      if (tx.isRoot) {
        root.add(currentNode);
      } else {
        final parentNode = nodes[tx.pid];
        parentNode?.add(currentNode);
      }
    }

    return root;
  }
}
