import 'package:hive_ce/hive_ce.dart';

import '../../core/filtering.dart';
import '../../core/log.dart';
import 'model.dart';

class TransactionsRepository {
  static const String boxName = 'transactions_box';

  final FilterIsolate _filter = FilterIsolate();

  Box<TransactionsModel> get _box => Hive.box<TransactionsModel>(boxName);

  Future<void> init() async {
    await _filter.init();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<TransactionsModel>(boxName);
    }
  }

  Future<TransactionsModel?> get(String tid) async {
    return _box.get(tid);
  }

  Future<void> add(TransactionsModel tx) async {
    logln(
      '[ADD] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
    );
    TransactionsModel ntx = tx;
    bool isClosable = await canClose(ntx);
    logln("[CLOSABLE] isclosable ${isClosable} - ${tx.isClosable}");
    if (tx.isClosable != isClosable) {
      ntx = ntx.copyWith(closable: isClosable);
    }

    await _rulesAdd(ntx);

    await _box.put(ntx.tid, ntx);
    await _box.flush();
  }

  Future<void> update(TransactionsModel tx) async {
    logln(
      '[UPDATE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
    );

    TransactionsModel ntx = tx;
    bool isClosable = await canClose(ntx);
    logln("[CLOSABLE] isclosable ${isClosable} - ${tx.isClosable}");
    if (tx.isClosable != isClosable) {
      ntx = ntx.copyWith(closable: isClosable);
    }

    await _rulesUpdate(ntx);

    await _box.put(ntx.tid, ntx);
    // await _box.flush();
  }

  Future<void> delete(TransactionsModel tx) async {
    await _rulesDelete(tx);

    logln(
      '[DELETE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
    );

    // This is to preseve tree sanity!
    _deleteLeaves(tx);

    await _box.delete(tx.tid);
    // await _box.flush();
  }

  Future<void> close(TransactionsModel tx) async {
    await _rulesClose(tx);

    TransactionsModel? otx = _box.get(tx.tid);
    if (otx == null) {
      throw Exception("Failed to close transaction");
    }

    TransactionsModel? target = await getCloseTargetParent(otx);
    if (target == null) {
      throw Exception("Failed to close transaction");
    }

    final leaves = await collectTerminalLeaves(target);
    final allClosed =
        leaves.isNotEmpty &&
        leaves
            // Current tx hasn't mutate status yet thus ignore it!
            .where((leaf) => leaf.tid != otx.tid)
            .every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    final newStatus = allClosed ? TransactionStatus.active.index : TransactionStatus.partial.index;
    final updatedTarget = target.copyWith(balance: target.balance + tx.balance, status: newStatus);

    final closedTx = tx.copyWith(balance: 0, status: TransactionStatus.closed.index);

    logln(
      '[CLOSING] ${tx.tid}|${tx.pid}|${tx.rid}|{tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
    );

    await _box.put(closedTx.tid, closedTx);
    // await _box.flush();

    await _box.put(updatedTarget.tid, updatedTarget);
    // await _box.flush();
  }

  Future<List<TransactionsModel>> getAll() async {
    final list = <TransactionsModel>[];
    for (final key in _box.keys) {
      final tx = _box.get(key);
      if (tx != null) list.add(tx);
    }
    return list;
  }

  Future<List<TransactionsModel>> getLeaf(TransactionsModel tx) async {
    final list = <TransactionsModel>[];
    for (final key in _box.keys) {
      final ltx = _box.get(key);
      if (ltx != null && ltx.pid == tx.tid) list.add(ltx);
    }
    return list;
  }

  Future<List<TransactionsModel>> filter(String query) async {
    final all = await getAll();
    final maps = all.map((e) => e.toMap()).toList();

    final filteredMaps = await _filter.filter(maps, query);
    return filteredMaps.map(TransactionsModel.fromMap).toList();
  }

  Future<List<TransactionsModel>> collectTerminalLeaves(TransactionsModel parent) async {
    final all = await getAll();

    final Map<String, List<TransactionsModel>> childrenMap = {};
    for (final tx in all) {
      childrenMap.putIfAbsent(tx.pid, () => []).add(tx);
    }

    List<TransactionsModel> dfs(TransactionsModel node) {
      final children = childrenMap[node.tid] ?? [];

      // No children → terminal leaf candidate
      if (children.isEmpty) {
        if (node.tid == parent.tid) return [];
        if (node.isRoot) return [];
        return [node];
      }

      // Recurse into children
      final leaves = <TransactionsModel>[];
      for (final child in children) {
        leaves.addAll(dfs(child));
      }
      return leaves;
    }

    return dfs(parent);
  }

  Future<TransactionsModel?> getCloseTargetParent(TransactionsModel tx) async {
    if (tx.isRoot) {
      return null;
    }

    final all = await getAll();

    final Map<String, TransactionsModel> byTid = {for (final t in all) t.tid: t};

    TransactionsModel? parent;
    String? pid = tx.pid;

    while (pid != null && pid.isNotEmpty) {
      final p = byTid[pid];
      if (p == null) break;

      if (p.rrId == tx.rrId) {
        parent = p;
        break;
      }

      pid = p.pid;
    }

    // Fallback: root with matching rid + rrId
    if (parent == null) {
      final roots = all.where((t) => t.isRoot && t.tid == tx.rid);

      if (roots.isNotEmpty) {
        final root = roots.first;
        if (root.rrId == tx.rrId) {
          parent = root;
        }
      }
    }

    return parent;
  }

  Future<bool> _rulesDelete(TransactionsModel tx) async {
    if (!tx.isRoot) {
      logln("Transaction: ${tx.tid} can be deleted as it is not root transaction");
      throw Exception("This transaction cannot be deleted.");
    }

    List<TransactionsModel> leaves = await collectTerminalLeaves(tx);
    final allClosed = leaves.isEmpty ? true : leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    if (!allClosed) {
      logln("Transaction: ${tx.tid} can be deleted as it still has active child transaction");
      throw Exception("This transaction cannot be deleted because related transactions are still in progress.");
    }

    return true;
  }

  Future<bool> _rulesUpdate(TransactionsModel tx) async {
    TransactionsModel? otx = _box.get(tx.tid);
    TransactionsModel? ptx = _box.get(tx.pid);
    TransactionsModel? rtx = _box.get(tx.rid);

    if (otx == null) {
      logln("[UPDATE RULE 1 FAIL] otx == null for tid=${tx.tid}");
      throw Exception("This transaction can no longer be found.");
    }

    if (otx.isRoot && (tx.pid != '0' || tx.rid != '0')) {
      logln("[UPDATE RULE 2 FAIL] Root tx cannot change pid/rid");
      throw Exception("This transaction cannot be changed in that way.");
    }

    if (otx.isLeaf && (ptx == null || rtx == null)) {
      logln("[UPDATE RULE 3 FAIL] Leaf missing parent or root: ptx=$ptx rtx=$rtx");
      throw Exception("This transaction is not linked correctly.");
    }

    if (tx.rrId <= 0 || tx.srId <= 0 || tx.srAmount <= 0 || tx.rrAmount <= 0 || tx.timestamp <= 0) {
      logln(
        "[UPDATE RULE 4 FAIL] Invalid fields: rrId=${tx.rrId}, srId=${tx.srId}, srAmount=${tx.srAmount}, rrAmount=${tx.rrAmount}, timestamp=${tx.timestamp}",
      );
      throw Exception("Some required transaction details are missing or invalid.");
    }

    List<TransactionsModel> leaves = await collectTerminalLeaves(tx);
    final targetCloser = await getCloseTargetParent(tx);
    final children = await getLeaf(tx);

    final hasChildren = children.isNotEmpty;
    final allClosed = leaves.isEmpty ? true : leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed);
    final spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);

    double balance = otx.rrAmount - spent;

    if (tx.rrId != otx.rrId || tx.rrAmount != otx.rrAmount || tx.srId != otx.srId || tx.srAmount != otx.srAmount) {
      if (hasChildren) {
        logln("[UPDATE RULE 5 FAIL] Cannot change SR/RR fields when hasChildren=true");
        throw Exception(
          "This transaction cannot change its accounts or amounts because related transactions depend on it.",
        );
      }
    }

    if (tx.status != otx.status) {
      switch (tx.statusEnum) {
        case TransactionStatus.inactive:
          if (!hasChildren) {
            logln("[UPDATE RULE 6A FAIL] inactive requires hasChildren=true");
            throw Exception("This transaction cannot be marked inactive.");
          }
          if (balance > 0) {
            logln("[UPDATE RULE 6A FAIL] inactive requires balance=0 but balance=$balance");
            throw Exception("This transaction still has remaining balance and cannot be marked inactive.");
          }
          break;

        case TransactionStatus.active:
          if (!hasChildren && tx.balance <= 0) {
            logln("[UPDATE RULE 6B FAIL] active requires balance>0 when no children");
            throw Exception("This transaction must have a positive balance to remain active.");
          }
          if (hasChildren && !allClosed) {
            logln("[UPDATE RULE 6B FAIL] active requires all children closed");
            throw Exception("All related transactions must be completed before this one can be active.");
          }
          break;

        case TransactionStatus.partial:
          if (!hasChildren) {
            logln("[UPDATE RULE 6C FAIL] partial requires hasChildren=true");
            throw Exception("This transaction cannot be marked as partially completed.");
          }
          if (hasChildren && allClosed) {
            logln("[UPDATE RULE 6C FAIL] partial cannot have all children closed");
            throw Exception(
              "This transaction cannot be marked as partial because all related transactions are already completed.",
            );
          }
          break;

        case TransactionStatus.closed:
          if (tx.isRoot) {
            logln("[UPDATE RULE 6D FAIL] root cannot be closed");
            throw Exception("This transaction cannot be closed directly.");
          }
          if (targetCloser == null) {
            logln("[UPDATE RULE 6D FAIL] closed requires targetCloser != null");
            throw Exception("This transaction is not ready to be closed yet.");
          }
          break;

        case TransactionStatus.unknown:
          break;
      }
    }

    if (tx.closable != otx.closable) {
      switch (tx.closable) {
        case true:
          if (tx.isRoot && !allClosed) {
            logln("[UPDATE RULE 7A FAIL] root closable=true requires allClosed=true");
            throw Exception("This transaction cannot be marked as closable yet.");
          }
          if (tx.isLeaf && !otx.isActive) {
            logln("[UPDATE RULE 7A FAIL] leaf closable=true requires otx.active");
            throw Exception("This transaction must be active before it can be marked as closable.");
          }
          if (tx.isLeaf && targetCloser == null) {
            logln("[UPDATE RULE 7A FAIL] leaf closable=true requires targetCloser!=null");
            throw Exception("This transaction cannot be marked as closable yet.");
          }
          break;

        case false:
          if (tx.isRoot && allClosed) {
            logln("[UPDATE RULE 7B FAIL] root closable=false cannot have allClosed=true");
            throw Exception("This transaction must remain closable.");
          }
          if (tx.isLeaf && otx.isActive && targetCloser != null) {
            logln("[UPDATE RULE 7B FAIL] leaf closable=false cannot have active+targetCloser");
            throw Exception("This transaction cannot be marked as not closable.");
          }
          break;
      }
    }

    return true;
  }

  Future<bool> _rulesAdd(TransactionsModel tx) async {
    TransactionsModel? ptx = _box.get(tx.pid);
    TransactionsModel? rtx = _box.get(tx.rid);

    if (tx.tid == '0') {
      logln("ADD RULE 1 FAIL tid=0");
      throw Exception("This transaction is invalid.");
    }

    if (tx.pid == '0' && tx.rid != '0') {
      logln("ADD RULE 2 FAIL pid=0 but rid!=0");
      throw Exception("This transaction is not linked correctly.");
    }

    if (tx.rid == '0' && tx.pid != '0') {
      logln("ADD RULE 3 FAIL rid=0 but pid!=0");
      throw Exception("This transaction is not linked correctly.");
    }

    if (tx.rrId <= 0 || tx.srId <= 0 || tx.srAmount <= 0 || tx.rrAmount <= 0 || tx.timestamp <= 0) {
      logln(
        "ADD RULE 4 FAIL invalid fields rrId=${tx.rrId} srId=${tx.srId} srAmount=${tx.srAmount} rrAmount=${tx.rrAmount} timestamp=${tx.timestamp}",
      );
      throw Exception("Some required transaction details are missing or invalid.");
    }

    if (tx.statusEnum != TransactionStatus.active) {
      logln("ADD RULE 5 FAIL status must be active");
      throw Exception("A new transaction must start as active.");
    }

    if (tx.isRoot) {
      if (tx.balance != tx.rrAmount) {
        logln("ADD RULE 6 FAIL root balance mismatch balance=${tx.balance} rrAmount=${tx.rrAmount}");
        throw Exception("The transaction balance does not match the expected amount.");
      }

      if (tx.closable != true) {
        logln("ADD RULE 7 FAIL root must be closable=true");
        throw Exception("This transaction must be marked as closable.");
      }
    }

    if (tx.isLeaf) {
      final targetCloser = await getCloseTargetParent(tx);

      if (rtx == null) {
        logln("ADD RULE 8 FAIL rtx=null rid=${tx.rid}");
        throw Exception("This transaction is not linked correctly.");
      }

      if (ptx == null) {
        logln("ADD RULE 9 FAIL ptx=null pid=${tx.pid}");
        throw Exception("This transaction is not linked correctly.");
      }

      if (tx.srId != ptx.rrId) {
        logln("ADD RULE 10 FAIL srId=${tx.srId} != parent.rrId=${ptx.rrId}");
        throw Exception("This transaction does not match the expected account.");
      }

      if (tx.srAmount > ptx.balance) {
        logln("ADD RULE 11 FAIL srAmount=${tx.srAmount} > parent.balance=${ptx.balance}");
        throw Exception("The transaction amount exceeds the available balance.");
      }

      if (tx.closable == true && targetCloser == null) {
        logln("ADD RULE 12 FAIL closable=true but no targetCloser");
        throw Exception("This transaction cannot be marked as closable yet.");
      }

      if (tx.closable == false && targetCloser != null) {
        logln("ADD RULE 13 FAIL closable=false but targetCloser exists");
        throw Exception("This transaction must be marked as closable.");
      }
    }

    return true;
  }

  Future<bool> _rulesClose(TransactionsModel tx) async {
    TransactionsModel? otx = _box.get(tx.tid);

    if (otx == null) {
      logln("CLOSE RULE 1 FAIL no otx == null");
      throw Exception("This transaction can no longer be found.");
    }

    if (otx.isRoot) {
      logln("CLOSE RULE 2 FAIL no otx.isRoot");
      throw Exception("This transaction cannot be closed directly.");
    }

    final targetCloser = await getCloseTargetParent(otx);

    if (targetCloser == null) {
      logln("CLOSE RULE 3 FAIL targetCloser == null");
      throw Exception("This transaction is not ready to be closed yet.");
    }

    return true;
  }

  Future<void> _deleteLeaves(TransactionsModel tx) async {
    final all = await getAll();
    for (final ttx in all) {
      if (tx.tid == ttx.rid || tx.tid == ttx.pid) {
        logln(
          '[DELETE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
        );

        _box.delete(ttx.tid);
      }
    }
  }

  Future<bool> canClose(TransactionsModel tx) async {
    if (tx.isRoot) {
      List<TransactionsModel> leaves = await collectTerminalLeaves(tx);
      return leaves.isEmpty ? true : leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed);
    }

    final targetCloser = await getCloseTargetParent(tx);
    return targetCloser != null;
  }
}
