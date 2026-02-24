import 'package:flutter/foundation.dart';

import '../../core/log.dart';
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
    await load();
  }

  Future<void> update(TransactionsModel tx) async {
    await repo.update(tx);
    await load();
  }

  Future<void> delete(String tid) async {
    await repo.delete(tid);
    await load();
  }

  Future<void> close(String tid) async {
    final tx = _items.firstWhere((t) => t.tid == tid);
    final originalBalance = tx.balance;

    await repo.update(tx.copyWith(balance: 0, status: TransactionStatus.closed.index));

    TransactionsModel? parent;
    String? pid = tx.pid;

    while (pid != null && pid.isNotEmpty) {
      final matches = _items.where((t) => t.tid == pid);
      if (matches.isEmpty) break;

      final p = matches.first;
      if (p.rrId == tx.srId) {
        parent = p;
        break;
      }

      pid = p.pid;
    }

    if (parent == null) {
      final roots = _items.where((t) => t.pid == "0" && t.rid == "0" && t.tid == tx.rid);
      if (roots.isNotEmpty) {
        final root = roots.first;
        if (root.rrId == tx.srId) {
          parent = root;
        }
      }
    }

    if (parent == null) {
      await load();
      return;
    }

    final updatedParent = parent.copyWith(balance: parent.balance + originalBalance);
    await repo.update(updatedParent);

    final leaves = _items.where(
      (t) =>
          t.rid == parent!.tid &&
          (t.status == TransactionStatus.active.index || t.status == TransactionStatus.partial.index),
    );

    final newStatus = leaves.isEmpty ? TransactionStatus.active.index : TransactionStatus.partial.index;

    await repo.update(updatedParent.copyWith(status: newStatus));

    logln(
      "[CLOSE] tid=${tx.tid} -> parent=${parent.tid} "
      "origBal=$originalBalance newParentBal=${updatedParent.balance} "
      "parentStatus=${TransactionStatus.values[newStatus].name}",
    );

    await load();
  }

  Future<void> removeRoot(String tid) async {
    await repo.delete(tid);

    final related = _items.where((t) => t.rid == tid).toList();
    for (final tx in related) {
      await repo.delete(tx.tid);
    }

    await load();
  }
}
