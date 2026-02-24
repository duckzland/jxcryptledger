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
    await markClosable(tx);
    await load();
  }

  Future<void> update(TransactionsModel tx) async {
    final ctx = _items.firstWhere((t) => t.tid == tx.tid);
    await repo.update(tx);
    await markClosable(tx, ctx: ctx);
    await load();
  }

  Future<void> delete(String tid) async {
    await repo.delete(tid);
    await load();
  }

  Future<void> closeLeaf(String tid) async {
    final tx = _items.firstWhere((t) => t.tid == tid);

    if (tx.pid == '0' && tx.rid == '0') {
      // Refused to close a root transaction
      await load();
      return;
    }

    TransactionsModel? parent = getCloseTargetParent(tid);

    // Refused to close a transaction that has no destination to close to
    if (parent == null) {
      await load();
      return;
    }

    final leaves = _items.where(
      (t) =>
          t.rid == parent.tid &&
          t.tid != tx.tid &&
          (t.status == TransactionStatus.active.index || t.status == TransactionStatus.partial.index),
    );

    final newStatus = leaves.isEmpty ? TransactionStatus.active.index : TransactionStatus.partial.index;
    final updatedParent = parent.copyWith(balance: parent.balance + tx.balance, status: newStatus);

    logln(
      "[CLOSE] tid=${tx.tid} -> parent=${parent.tid} "
      "origBal=${tx.balance} newParentBal=${updatedParent.balance} "
      "parentStatus=${TransactionStatus.values[newStatus].name}",
    );

    await repo.update(tx.copyWith(balance: 0, status: TransactionStatus.closed.index));
    await repo.update(updatedParent);

    await load();
  }

  Future<void> removeRoot(String tid) async {
    final tx = _items.firstWhere((t) => t.tid == tid);
    if (tx.pid != '0' || tx.rid != '0') {
      // Refused to delete a non-root transaction
      await load();
      return;
    }

    await repo.delete(tid);

    final related = _items.where((t) => t.rid == tid).toList();
    for (final tx in related) {
      await repo.delete(tx.tid);
    }

    await load();
  }

  TransactionsModel? getCloseTargetParent(String tid) {
    final tx = _items.firstWhere((t) => t.tid == tid);

    if (tx.pid == '0' && tx.rid == '0') {
      return null;
    }

    TransactionsModel? parent;
    String? pid = tx.pid;

    while (pid != null && pid.isNotEmpty) {
      final matches = _items.where((t) => t.tid == pid);
      if (matches.isEmpty) break;

      final p = matches.first;
      if (p.rrId == tx.rrId) {
        // logln("Checking: pid: $pid, ${p.rrId} - ${tx.rrId}");
        parent = p;
        break;
      }

      //   logln("Checking: pid: $pid, ${p.rrId} - ${tx.rrId}");

      pid = p.pid;
    }

    if (parent == null) {
      final roots = _items.where((t) => t.pid == "0" && t.rid == "0" && t.tid == tx.rid);
      if (roots.isNotEmpty) {
        final root = roots.first;
        if (root.rrId == tx.rrId) {
          parent = root;
        }
      }
    }

    return parent;
  }

  Future<void> markClosable(TransactionsModel tx, {TransactionsModel? ctx}) async {
    bool closable = false;

    if (!tx.isRoot && tx.statusEnum == TransactionStatus.active) {
      // For update, honor rrId change
      if (ctx == null || ctx.rrId != tx.rrId) {
        final cp = getCloseTargetParent(tx.tid);
        if (cp != null) {
          closable = true;
        }
      }
    }

    if (tx.closable != closable) {
      final updated = tx.copyWith(closable: closable);
      await repo.update(updated);
    }
  }
}
