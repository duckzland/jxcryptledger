import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/locator.dart';
import '../../../widgets/panel.dart';
import '../../cryptos/controller.dart';
import '../controller.dart';
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
  final CryptosController _cryptosController = locator<CryptosController>();
  final TransactionsController _txController = locator<TransactionsController>();

  late IndexedTreeNode<TransactionsModel> _root;
  late Map<String, IndexedTreeNode<TransactionsModel>> _nodes;
  late int _sortMode = widget.sortMode;
  TreeViewController<TransactionsModel, IndexedTreeNode<TransactionsModel>>? scrollController;

  @override
  void initState() {
    super.initState();
    _root = _treeBuildNodes(widget.transactions);
  }

  @override
  void didUpdateWidget(covariant TransactionHistory oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) {
      return;
    }

    if (_txController.isBothEqualGroup(oldWidget.transactions, widget.transactions)) {
      return;
    }

    if (oldWidget.transactions.isEmpty && widget.transactions.isNotEmpty) {
      _root = _treeBuildNodes(widget.transactions);
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
      _root = _treeBuildNodes(widget.transactions);
      setState(() {});
      return;
    }

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
              scrollController = controller;
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

      if (parent != null) {
        _nodes[tx.tid] = node;

        switch (_sortMode) {
          case 0:
            final symbol = _cryptosController.getSymbol(tx.srId) ?? tx.srId.toString();
            final children = parent.childrenAsList.cast<IndexedTreeNode<TransactionsModel>>();
            final idx = children.indexWhere((c) {
              final symbolA = _cryptosController.getSymbol(c.data!.srId) ?? c.data!.srId.toString();
              return symbol.trim().toLowerCase().characters.first.compareTo(symbolA.trim().toLowerCase().characters.first) < 0;
            });
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

        // This tree package is buggy, "Root" wont got scrolled when added while "leaves" does.
        if (tx.isRoot) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollController?.scrollToItem(node);
          });
        }
      }
    }
  }

  void _treeUpdateTxs(List<TransactionsModel> oldTxs, List<TransactionsModel> newTxs) {
    final oldIds = oldTxs.map((t) => t.tid).toSet();
    final newIds = newTxs.map((t) => t.tid).toSet();
    final updated = newIds.intersection(oldIds);

    for (final tid in updated) {
      final ntx = newTxs.firstWhere((t) => t.tid == tid);
      final node = _nodes[tid];

      if (node == null || _txController.isBothEqual(ntx, node.data!)) {
        continue;
      }

      final oldTx = node.data!;
      node.data = ntx;
      _nodes[tid] = node;

      bool doScroll = false;
      IndexedTreeNode<TransactionsModel>? txd;

      switch (_sortMode) {
        case 0:
          if (oldTx.srId == ntx.srId || !oldTx.isRoot) {
            break;
          }

          final ntxF = (_cryptosController.getSymbol(ntx.srId) ?? ntx.srId.toString()).trim().toLowerCase().characters.first;

          for (final entry in _nodes.values) {
            final ctx = entry.data!;
            final ctxF = (_cryptosController.getSymbol(ctx.srId) ?? ctx.srId.toString()).trim().toLowerCase().characters.first;

            if (!ctx.isRoot || ctx.tid == ntx.tid || ntxF.compareTo(ctxF) > 0) {
              continue;
            }

            if (txd == null) {
              txd = entry;
              continue;
            }

            final txdF = (_cryptosController.getSymbol(txd.data!.srId) ?? txd.data!.srId.toString()).trim().toLowerCase().characters.first;
            if (ctxF.compareTo(txdF) < 0) {
              txd = entry;
            }
          }

          doScroll = true;
          _root.remove(node);
          (txd != null) ? _root.insertBefore(txd, node) : _root.add(node);

          break;

        case 1:
          if (oldTx.timestamp == ntx.timestamp || !oldTx.isRoot) {
            break;
          }

          for (final entry in _nodes.values) {
            final ctx = entry.data!;

            if (!ctx.isRoot ||
                ctx.tid == ntx.tid ||
                ntx.sanitizedTimestamp < ctx.sanitizedTimestamp ||
                (txd != null && ctx.sanitizedTimestamp < txd.data!.sanitizedTimestamp)) {
              continue;
            }

            txd = entry;
          }

          doScroll = true;
          _root.remove(node);
          (txd != null) ? _root.insertAfter(txd, node) : _root.insert(0, node);

          break;

        case 2:
          if (oldTx.timestamp == ntx.timestamp || !oldTx.isRoot) {
            break;
          }

          for (final entry in _nodes.values) {
            final ctx = entry.data!;

            if (!ctx.isRoot ||
                ctx.tid == ntx.tid ||
                ntx.sanitizedTimestamp > ctx.sanitizedTimestamp ||
                (txd != null && ctx.sanitizedTimestamp > txd.data!.sanitizedTimestamp)) {
              continue;
            }

            txd = entry;
          }

          doScroll = true;
          _root.remove(node);
          (txd != null) ? _root.insertAfter(txd, node) : _root.insert(0, node);

          break;
      }

      if (doScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollController?.scrollToItem(node);
        });
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
}
