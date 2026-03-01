import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:jxcryptledger/features/transactions/buttons.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../widgets/header.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../model.dart';

class TransactionHistory extends StatefulWidget {
  final List<TransactionsModel> transactions;

  const TransactionHistory({super.key, required this.transactions});

  @override
  TransactionHistoryState createState() => TransactionHistoryState();
}

class TransactionHistoryState extends State<TransactionHistory> {
  final CryptosController _cryptosController = locator<CryptosController>();

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
            key: ValueKey(widget.transactions.map((e) => "${e.tid}-${e.timestamp}").join('|')),
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
              void expandAll(TreeNode node) {
                controller.expandNode(node as TreeNode<TransactionsModel>);
                for (final child in node.children.values) {
                  expandAll(child as TreeNode<TransactionsModel>);
                }
              }

              for (final child in _root.children.values) {
                expandAll(child as TreeNode<TransactionsModel>);
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

  Widget _buildTransactionPanel(TransactionsModel tx, TreeNode<TransactionsModel> node) {
    final sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? 'Unknown';
    final resultSymbol = _cryptosController.getSymbol(tx.rrId) ?? 'Unknown';

    Color bgColor = AppTheme.rowHeaderBg;
    if (tx.statusEnum == TransactionStatus.inactive) {
      bgColor = AppTheme.mutedBg;
    }
    if (tx.statusEnum == TransactionStatus.closed) {
      bgColor = AppTheme.closedBg;
    }

    Color fgColor = AppTheme.text;
    if (tx.statusEnum == TransactionStatus.inactive) {
      fgColor = AppTheme.textMuted;
    }
    if (tx.statusEnum == TransactionStatus.closed) {
      fgColor = AppTheme.textMuted;
    }

    return Card(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      color: bgColor,
      child: ListTile(
        title: WidgetsHeader(
          titleColor: fgColor,
          title: "${tx.srAmountText} $sourceSymbol → ${tx.balanceText} $resultSymbol",
          subtitle: "${tx.timestampAsFormattedDate} - ${tx.statusText}",
        ),
        trailing: Padding(
          padding: !node.isLeaf ? EdgeInsets.only(right: 20) : EdgeInsetsGeometry.zero,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TransactionsButtons(
                tx: tx,
                onAction: () {
                  refreshTree();

                  if (mounted) {
                    setState(() {
                      _root = _buildTreeNodes(widget.transactions);
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
