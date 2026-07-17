import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/runtime/locator.dart';
import '../../../mixins/state.dart';
import '../../../widgets/buttons/action.dart';
import '../../../widgets/header.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
import '../model.dart';
import '../widgets/cards/simple_tree.dart';

class TransactionsDialogsDetails extends StatelessWidget with MixinsState {
  final TransactionsModel tx;

  const TransactionsDialogsDetails({super.key, required this.tx});

  TransactionsController get _txController => locator<TransactionsController>();
  CryptosController get _cryptosController => locator<CryptosController>();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 1200),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 30,
            children: [
              const Text("Transaction Information", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),

              Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 0, children: [_buildInformation()]),

              WidgetsHeader(title: tx.noteText ?? "No notes available", subtitle: "Notes", reversed: true),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 5,
                children: [
                  WidgetsHeader(title: "", subtitle: "History", reversed: true),
                  SizedBox(width: double.infinity, height: calculateAdjustedMaxHeight(), child: _buildHistory()),
                ],
              ),

              Padding(
                padding: const EdgeInsets.only(top: 15.0, bottom: 5),
                child: Wrap(
                  direction: Axis.horizontal,
                  runSpacing: 20,
                  spacing: 10,
                  runAlignment: WrapAlignment.center,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [WidgetsButtonsAction(label: 'Close', onPressed: (_) => Navigator.pop(context))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformation() {
    final srSymbol = _cryptosController.getSymbol(tx.srId) ?? 'Unknown Coin';
    final rrSymbol = _cryptosController.getSymbol(tx.rrId) ?? 'Unknown Coin';

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return Row(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: WidgetsHeader(title: tx.timestampAsFormattedDate, subtitle: "Date", reversed: true),
              ),
              Expanded(
                child: WidgetsHeader(title: "${tx.srAmountText} $srSymbol", subtitle: "From", reversed: true),
              ),
              Expanded(
                child: WidgetsHeader(title: "${tx.rrAmountText} $rrSymbol", subtitle: "To", reversed: true),
              ),
              Expanded(
                child: WidgetsHeader(title: tx.rateText, subtitle: "Rate", reversed: true),
              ),
              Expanded(
                child: WidgetsHeader(title: "${tx.balanceText} $rrSymbol", subtitle: "Balance", reversed: true),
              ),
              Expanded(
                child: WidgetsHeader(title: tx.statusText, subtitle: "Status", reversed: true),
              ),
            ],
          );
        } else {
          return Column(
            spacing: 20,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WidgetsHeader(title: tx.timestampAsFormattedDate, subtitle: "Date", reversed: true),
              WidgetsHeader(title: "${tx.srAmountText} $srSymbol", subtitle: "From", reversed: true),
              WidgetsHeader(title: "${tx.rrAmountText} $rrSymbol", subtitle: "To", reversed: true),
              WidgetsHeader(title: tx.rateText, subtitle: "Rate", reversed: true),
              WidgetsHeader(title: "${tx.balanceText} $rrSymbol", subtitle: "Balance", reversed: true),
              WidgetsHeader(title: tx.statusText, subtitle: "Status", reversed: true),
            ],
          );
        }
      },
    );
  }

  Widget _buildHistory() {
    final root = _treeBuildNodes();
    return TreeView.indexed(
      key: PageStorageKey('detail-tree-history-${tx.uuid}'),
      tree: root,
      padding: const EdgeInsets.only(left: 16),
      showRootNode: false,
      indentation: const Indentation(style: IndentStyle.roundJoint, color: AppTheme.treeConnector),
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
          for (final child in root.childrenAsList) {
            controller.expandAllChildren(child as IndexedTreeNode<TransactionsModel>, recursive: true);
          }
        });
      },
      builder: (context, node) {
        final stx = node.data;
        if (stx == null) return const SizedBox.shrink();
        return TransactionsWidgetsCardsSimpleTree(key: ValueKey(stx.tid), tx: stx, node: node, isActive: stx.uuid == tx.uuid);
      },
    );
  }

  IndexedTreeNode<TransactionsModel> _treeBuildNodes() {
    List<TransactionsModel> txs = _txController.collectBranchWithTarget(tx);

    final root = IndexedTreeNode<TransactionsModel>.root();
    final nodes = <String, IndexedTreeNode<TransactionsModel>>{};

    for (final ttx in txs) {
      nodes[ttx.tid] = IndexedTreeNode<TransactionsModel>(key: ttx.tid, data: ttx);
    }

    for (final ttx in txs) {
      final currentNode = nodes[ttx.tid.toString()]!;
      if (ttx.isRoot) {
        root.add(currentNode);
      } else {
        final parentNode = nodes[ttx.pid];
        parentNode?.add(currentNode);
      }
    }

    return root;
  }

  static Future<void> show(BuildContext context, TransactionsModel transaction) {
    return showDialog(
      context: context,
      builder: (_) => TransactionsDialogsDetails(tx: transaction),
    );
  }

  double calculateAdjustedMaxHeight() {
    List<TransactionsModel> txs = _txController.collectBranchWithTarget(tx);
    double maxHeight = states.get('viewport-height', defaultValue: -1.00);

    final double itemHeight = 77;
    final double topOffset = 300;
    final double screenPercentage = 0.8;
    final int maxItems = 3;

    double suggestedHeight = txs.length * itemHeight;
    double minimumHeight = 3 * itemHeight;

    if (maxHeight < minimumHeight) {
      return suggestedHeight;
    }

    maxHeight -= topOffset;
    maxHeight = maxHeight * screenPercentage;
    if (maxHeight > 0 && suggestedHeight > maxHeight) {
      final rowsFit = (maxHeight / itemHeight).floor();

      int clampedRows;
      if (txs.length >= maxItems) {
        clampedRows = rowsFit < maxItems ? maxItems : rowsFit;
      } else {
        clampedRows = rowsFit;
      }

      if (clampedRows > txs.length) {
        clampedRows = txs.length;
      }

      final maxRows = clampedRows.toDouble();

      suggestedHeight = (maxRows * itemHeight);
    }

    return suggestedHeight;
  }
}
