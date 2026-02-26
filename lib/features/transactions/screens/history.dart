import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:jxcryptledger/features/transactions/buttons.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../widgets/header.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/repository.dart';
import '../model.dart';

class TransactionHistory extends StatefulWidget {
  final List<TransactionsModel> transactions;

  const TransactionHistory({super.key, required this.transactions});

  @override
  TransactionHistoryState createState() => TransactionHistoryState();
}

class TransactionHistoryState extends State<TransactionHistory> {
  final CryptosRepository _cryptosRepo = locator<CryptosRepository>();

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
          child: TreeView.simple(
            tree: _root,
            showRootNode: false,
            indentation: const Indentation(style: IndentStyle.roundJoint),
            expansionIndicatorBuilder: (context, node) => ChevronIndicator.rightDown(
              tree: node,
              color: AppTheme.text,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.centerRight,
            ),
            onTreeReady: (controller) {
              for (final level1 in _root.children.values) {
                controller.expandNode(level1 as TreeNode<TransactionsModel>);

                for (final level2 in level1.children.values) {
                  controller.expandNode(level2 as TreeNode<TransactionsModel>);
                }
              }
            },

            builder: (context, node) {
              final tx = node.data;
              if (tx == null) return const SizedBox.shrink();
              return _buildTransactionPanel(tx, node);
            },
          ),
        ),
      ),
    );
  }

  TreeNode<TransactionsModel> _buildTreeNodes(List<TransactionsModel> txs) {
    final root = TreeNode<TransactionsModel>.root();
    final nodes = <String, TreeNode<TransactionsModel>>{};

    for (final tx in txs) {
      nodes[tx.tid.toString()] = TreeNode<TransactionsModel>(key: tx.tid.toString(), data: tx);
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

  Widget _buildTransactionPanel(TransactionsModel tx, TreeNode<TransactionsModel> node) {
    final sourceSymbol = _cryptosRepo.getSymbol(tx.srId) ?? 'Unknown';
    final resultSymbol = _cryptosRepo.getSymbol(tx.rrId) ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(top: 4, bottom: 4),

      color: AppTheme.rowHeaderBg,
      child: ListTile(
        title: WidgetsHeader(
          title: "${tx.srAmountText} $sourceSymbol → ${tx.balanceText} $resultSymbol",
          subtitle: "${tx.timestampAsDate} - ${tx.statusText}",
        ),
        trailing: Padding(
          padding: !node.isLeaf ? EdgeInsets.only(right: 20) : EdgeInsetsGeometry.zero,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TransactionsButtons(
                tx: tx,
                onAction: () {
                  // Update model, then refresh tree
                  refreshTree();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
