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
    _root = _buildTreeNodes(widget.transactions);
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

    updateTree(oldWidget.transactions, widget.transactions);
    setState(() {});
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

    for (final tid in updated) {
      final newTx = newTxs.firstWhere((t) => t.tid == tid);
      final node = _nodes[tid];

      if (node != null) {
        final oldTx = node.data!;
        node.data = newTx;
        _nodes[tid] = node;

        if (oldTx.isRoot) {
          bool doScroll = false;

          switch (_sortMode) {
            case 0:
              if (oldTx.srId != newTx.srId) {
                IndexedTreeNode<TransactionsModel>? target;
                final newSymbol = _cryptosController.getSymbol(newTx.srId) ?? newTx.srId.toString();
                final newFirstChar = newSymbol.trim().toLowerCase().characters.first;

                for (final entry in _nodes.values) {
                  final ctx = entry.data!;
                  if (ctx.isRoot && ctx.tid != newTx.tid) {
                    final symbolA = _cryptosController.getSymbol(ctx.srId) ?? ctx.srId.toString();
                    final firstCharA = symbolA.trim().toLowerCase().characters.first;
                    final comp = newFirstChar.compareTo(firstCharA);

                    if (comp <= 0) {
                      if (target != null) {
                        final targetFirstChar = (_cryptosController.getSymbol(target.data!.srId) ?? target.data!.srId.toString())
                            .trim()
                            .toLowerCase()
                            .characters
                            .first;

                        final tcomp = firstCharA.compareTo(targetFirstChar);
                        if (tcomp < 0) {
                          target = entry;
                        }
                      } else {
                        target = entry;
                      }
                    }
                  }
                }

                _root.remove(node);
                doScroll = true;

                if (target != null) {
                  _root.insertBefore(target, node);
                } else {
                  _root.add(node);
                }
              }
              break;

            case 1:
              if (oldTx.timestamp != newTx.timestamp) {
                IndexedTreeNode<TransactionsModel>? target;
                for (final entry in _nodes.values) {
                  final ctx = entry.data!;
                  if (ctx.isRoot && ctx.tid != newTx.tid && newTx.sanitizedTimestamp > ctx.sanitizedTimestamp) {
                    if (target == null || ctx.sanitizedTimestamp > target.data!.sanitizedTimestamp) {
                      target = entry;
                    }
                  }
                }

                _root.remove(node);
                doScroll = true;

                if (target != null) {
                  _root.insertAfter(target, node);
                } else {
                  _root.insert(0, node);
                }
              }
              break;

            case 2:
              if (oldTx.timestamp != newTx.timestamp) {
                IndexedTreeNode<TransactionsModel>? target;
                for (final entry in _nodes.values) {
                  final ctx = entry.data!;
                  if (ctx.isRoot && ctx.tid != newTx.tid && newTx.sanitizedTimestamp < ctx.sanitizedTimestamp) {
                    if (target == null || ctx.sanitizedTimestamp < target.data!.sanitizedTimestamp) {
                      target = entry;
                    }
                  }
                }

                _root.remove(node);
                doScroll = true;

                if (target != null) {
                  _root.insertAfter(target, node);
                } else {
                  _root.insert(0, node);
                }
              }
              break;
          }

          if (doScroll) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollController?.scrollToItem(node);
            });
          }
        }
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
