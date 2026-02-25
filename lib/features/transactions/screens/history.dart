import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:jxcryptledger/features/transactions/buttons.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../widgets/header.dart';
import '../../cryptos/repository.dart';
import '../model.dart';

class TransactionHistory extends StatelessWidget {
  final List<TransactionsModel> transactions;
  final CryptosRepository _cryptosRepo = locator<CryptosRepository>();

  TransactionHistory({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final root = _buildTreeNodes(transactions);

    return Scaffold(
      body: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.separator),
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.panelBg,
        ),
        child: TreeView.simple(
          tree: root,
          showRootNode: false,
          indentation: const Indentation(style: IndentStyle.roundJoint),
          expansionIndicatorBuilder: (context, node) =>
              ChevronIndicator.rightDown(tree: node, color: AppTheme.primary, padding: const EdgeInsets.all(8)),
          builder: (context, node) {
            final tx = node.data;
            if (tx == null) return const SizedBox.shrink();
            return _buildTransactionPanel(tx);
          },
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

  Widget _buildTransactionPanel(TransactionsModel tx) {
    String sourceSymbol = _cryptosRepo.getSymbol(tx.srId) ?? 'Unknown';
    String resultSymbol = _cryptosRepo.getSymbol(tx.rrId) ?? 'Unknown';
    return Card(
      color: AppTheme.rowHeaderBg,
      child: ListTile(
        title: WidgetsTitle(
          title: "${tx.timestampAsDate} ${tx.srAmountText} $sourceSymbol to ${tx.balanceText} $resultSymbol",
          subtitle: tx.statusText,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TransactionsButtons(
              tx: tx,
              onAction: () {
                // Need state here!
              },
            ),
          ],
        ),
      ),
    );
  }
}
