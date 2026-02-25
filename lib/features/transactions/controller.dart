import 'package:flutter/foundation.dart';

import 'model.dart';
import 'repository.dart';

class TransactionsController extends ChangeNotifier {
  final TransactionsRepository repo;

  List<TransactionsModel> _items = [];
  List<TransactionsModel> get items => _items;

  TransactionsController(this.repo);

  Future<void> load() async {
    _items = await repo.getAll();
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      await load();
      return;
    }

    _items = await repo.filter(query);
    notifyListeners();
  }

  Future<void> add(TransactionsModel tx) async {
    await repo.add(tx);
    await markClosable(tx);
    await load();
  }

  Future<void> update(TransactionsModel tx) async {
    await repo.update(tx);
    await markClosable(tx);
    await load();
  }

  Future<void> delete(TransactionsModel tx) async {
    await repo.delete(tx);
    await load();
  }

  Future<void> closeLeaf(TransactionsModel tx) async {
    if (tx.isRoot) {
      return;
    }

    TransactionsModel? parent = getCloseTargetParent(tx);

    if (parent == null) {
      return;
    }

    final leaves = collectTerminalLeaves(parent);
    final allClosed =
        leaves.isNotEmpty &&
        leaves
            // Current tx hasn't mutate status yet thus ignore it!
            .where((leaf) => leaf.tid != tx.tid)
            .every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    final newStatus = allClosed ? TransactionStatus.active.index : TransactionStatus.partial.index;
    final updatedParent = parent.copyWith(balance: parent.balance + tx.balance, status: newStatus);

    final closedTx = tx.copyWith(balance: 0, status: TransactionStatus.closed.index);

    await repo.update(closedTx);
    await repo.update(updatedParent);
    await load();
  }

  Future<void> removeRoot(TransactionsModel tx) async {
    if (tx.isLeaf) {
      return;
    }

    await repo.delete(tx);

    final related = _items.where((t) => t.rid == tx.tid).toList();
    for (final tx in related) {
      await repo.delete(tx);
    }

    await load();
  }

  TransactionsModel? getCloseTargetParent(TransactionsModel tx) {
    if (tx.isRoot) {
      return null;
    }

    TransactionsModel? parent;
    String? pid = tx.pid;

    while (pid != null && pid.isNotEmpty) {
      final matches = _items.where((t) => t.tid == pid);
      if (matches.isEmpty) break;

      final p = matches.first;
      if (p.rrId == tx.rrId) {
        parent = p;
        break;
      }

      pid = p.pid;
    }

    if (parent == null) {
      final roots = _items.where((t) => t.isRoot && t.tid == tx.rid);
      if (roots.isNotEmpty) {
        final root = roots.first;
        if (root.rrId == tx.rrId) {
          parent = root;
        }
      }
    }

    return parent;
  }

  Future<void> markClosable(TransactionsModel tx) async {
    if (tx.isRoot) {
      final leaves = collectTerminalLeaves(tx);
      final allClosed = leaves.isEmpty ? true : leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed);
      final updated = tx.copyWith(closable: allClosed ? true : false);

      if (updated.closable != tx.closable) {
        await repo.update(updated);
      }
      return;
    }

    bool closable = false;
    if (tx.isActive) {
      final cp = getCloseTargetParent(tx);
      if (cp != null) {
        closable = true;
      }
    }

    if (tx.closable != closable) {
      final updated = tx.copyWith(closable: closable);
      await repo.update(updated);
    }
  }

  List<TransactionsModel> collectTerminalLeaves(TransactionsModel parent) {
    List<TransactionsModel> collect(TransactionsModel node) {
      final children = _items.where((t) => t.pid == node.tid).toList();

      if (children.isEmpty) {
        if (node.tid == parent.tid) {
          return [];
        }

        if (node.isRoot) {
          return [];
        }

        return [node];
      }

      final leaves = <TransactionsModel>[];
      for (final child in children) {
        leaves.addAll(collect(child));
      }

      return leaves;
    }

    final result = collect(parent);
    return result;
  }
}
