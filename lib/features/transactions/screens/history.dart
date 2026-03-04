import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:jxcryptledger/features/transactions/buttons.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../core/log.dart';
import '../../../core/utils.dart';
import '../../../widgets/header.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../model.dart';

class TransactionHistory extends StatefulWidget {
  final List<TransactionsModel> transactions;

  const TransactionHistory({super.key, required this.transactions});

  @override
  TransactionHistoryState createState() => TransactionHistoryState();
}

class TransactionHistoryState extends State<TransactionHistory> {
  final CryptosController _cryptosController = locator<CryptosController>();
  final TransactionsController _txController = locator<TransactionsController>();

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
            expansionIndicatorBuilder: (context, node) => ChevronIndicator.rightDown(
              tree: node,
              color: AppTheme.text,
              padding: const EdgeInsets.symmetric(horizontal: 22),
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
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_txController.collectBranchResultAmount(tx), _txController.hasLeaf(tx)]),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: ListTile(title: Text("Loading...")));
        }

        if (snapshot.hasError) {
          return Card(child: ListTile(title: Text("Error loading amounts")));
        }

        final hasLeaf = snapshot.data![1] as bool;
        final capital = tx.srAmount;
        final balance = snapshot.data![0] as double;
        final profit = balance - capital;
        final profitPercentage = (capital == 0) ? 0.0 : ((balance - capital) / capital) * 100;

        Color bgColor = AppTheme.rowHeaderBg;
        Color fgColor = AppTheme.text;

        if (tx.statusEnum == TransactionStatus.inactive) {
          bgColor = AppTheme.mutedBg;
          fgColor = AppTheme.textMuted;
        }
        if (tx.statusEnum == TransactionStatus.closed) {
          bgColor = AppTheme.closedBg;
          fgColor = AppTheme.textMuted;
        }

        Color plColor = fgColor;
        String prefix = "";
        if (profitPercentage > 0) {
          plColor = const Color.fromARGB(255, 112, 225, 104);
          prefix = "+";
        } else if (profitPercentage < 0) {
          plColor = const Color.fromARGB(255, 255, 109, 109);
        }

        String srSymbol = _cryptosController.getSymbol(tx.srId) ?? 'Unknown';
        String rrSymbol = _cryptosController.getSymbol(tx.rrId) ?? 'Unknown';

        return Card(
          margin: const EdgeInsets.only(top: 4, bottom: 4, left: 0, right: 16),
          color: bgColor,
          child: ListTile(
            title: Row(
              children: [
                Row(
                  children: [
                    WidgetsHeader(
                      titleColor: fgColor,
                      title: "${tx.srAmountText} $srSymbol → ${tx.rrAmountText} $rrSymbol",
                      subtitle: tx.timestampAsFormattedDate,
                      reversed: true,
                    ),
                    const SizedBox(width: 25),
                    WidgetsHeader(titleColor: fgColor, title: tx.statusText, subtitle: "Status", reversed: true),
                    const SizedBox(width: 25),
                    WidgetsHeader(titleColor: fgColor, title: "${tx.balanceText} $rrSymbol", subtitle: "Available", reversed: true),
                  ],
                ),
                Expanded(
                  child: hasLeaf && balance > 0
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            WidgetsHeader(
                              titleColor: fgColor,
                              title: "${Utils.formatSmartDouble(capital)} $srSymbol",
                              subtitle: "Total Capital",
                              reversed: true,
                            ),
                            const SizedBox(width: 25),
                            WidgetsHeader(
                              titleColor: fgColor,
                              title: "${Utils.formatSmartDouble(balance)} $srSymbol",
                              subtitle: "Current Balance",
                              reversed: true,
                            ),
                            const SizedBox(width: 25),
                            WidgetsHeader(
                              titleColor: plColor,
                              title: "$prefix${Utils.formatSmartDouble(profit)} $srSymbol",
                              subtitle: "Profit / Loss",
                              reversed: true,
                            ),
                            const SizedBox(width: 25),
                            WidgetsHeader(
                              titleColor: plColor,
                              title: "$prefix$profitPercentage%",
                              subtitle: "Profit / Loss %",
                              reversed: true,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            trailing: TransactionsButtons(
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
          ),
        );
      },
    );
  }
}
