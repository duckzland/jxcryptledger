import 'dart:math';

import 'package:hive_ce/hive_ce.dart';

import '../../app/exceptions.dart';
import '../../core/filtering.dart';
import '../../core/log.dart';
import 'model.dart';

class TransactionsRepository {
  static const String boxName = 'transactions_box';
  final bool debugLogs = true;

  final FilterIsolate _filter = FilterIsolate();

  Box<TransactionsModel> get _box => Hive.box<TransactionsModel>(boxName);

  Future<void> init() async {
    await _filter.init();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<TransactionsModel>(boxName);
    }
  }

  String generateTid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();

    while (true) {
      final now = DateTime.now().microsecondsSinceEpoch;
      final timePart = now.toRadixString(36).padLeft(4, '0');
      final timeSuffix = timePart.substring(timePart.length - 4);
      final randomPart = String.fromCharCodes(
        Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
      );

      final id = '$timeSuffix$randomPart';
      if (!_box.containsKey(id)) {
        if (debugLogs) {
          logln('Generated unique ID: $id');
        }
        return id;
      }

      if (debugLogs) {
        logln('Collision detected for $id, retrying...');
      }
    }
  }

  Future<TransactionsModel?> get(String tid) async {
    return _box.get(tid);
  }

  Future<void> add(TransactionsModel tx) async {
    if (debugLogs) {
      logln(
        '[ADD] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    TransactionsModel ntx = tx;

    bool isClosable;
    try {
      isClosable = await canClose(ntx);
    } catch (e) {
      isClosable = false;
    }

    if (tx.isClosable != isClosable) {
      ntx = ntx.copyWith(closable: isClosable);
    }

    await canAdd(ntx);

    await _box.put(ntx.tid, ntx);
    await _box.flush();
  }

  Future<void> update(TransactionsModel tx) async {
    if (debugLogs) {
      logln(
        '[UPDATE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    TransactionsModel ntx = tx;
    bool isClosable;
    try {
      isClosable = await canClose(ntx);
    } catch (e) {
      isClosable = false;
    }

    if (tx.isClosable != isClosable) {
      ntx = ntx.copyWith(closable: isClosable);
    }

    await canUpdate(ntx);

    await _box.put(ntx.tid, ntx);
  }

  Future<void> delete(TransactionsModel tx) async {
    await canDelete(tx);

    if (debugLogs) {
      logln(
        '[DELETE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    // This is to preseve tree sanity!
    _deleteLeaves(tx);

    await _box.delete(tx.tid);
  }

  Future<void> close(TransactionsModel tx) async {
    await canClose(tx);

    TransactionsModel? otx = _box.get(tx.tid);
    if (otx == null) {
      return; // canClose already check and throw
    }

    TransactionsModel? target = await getCloseTargetParent(otx);
    if (target == null) {
      return; // canClose already check and throw
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

    if (debugLogs) {
      logln(
        '[CLOSING] ${tx.tid}|${tx.pid}|${tx.rid}|{tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    await _box.put(closedTx.tid, closedTx);
    await _box.put(updatedTarget.tid, updatedTarget);
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

      if (children.isEmpty) {
        if (node.tid == parent.tid) return [];
        if (node.isRoot) return [];
        return [node];
      }

      final leaves = <TransactionsModel>[];
      for (final child in children) {
        leaves.addAll(dfs(child));
      }
      return leaves;
    }

    return dfs(parent);
  }

  Future<List<TransactionsModel>> collectAllLeaves(TransactionsModel parent) async {
    final all = await getAll();

    final Map<String, List<TransactionsModel>> childrenMap = {};
    for (final tx in all) {
      childrenMap.putIfAbsent(tx.pid, () => []).add(tx);
    }

    List<TransactionsModel> dfs(TransactionsModel node) {
      final children = childrenMap[node.tid] ?? [];

      if (children.isEmpty) {
        return (node.tid == parent.tid) ? [] : [node];
      }

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

  Future<bool> canDelete(TransactionsModel tx) async {
    if (!tx.isRoot) {
      throw ValidationException(
        2001,
        "[DELETE RULE 1 FAIL] tx.isRoot == false tid=${tx.tid}",
        "This transaction cannot be deleted.",
        silent: !debugLogs,
      );
    }

    final List<TransactionsModel> terminals = await collectTerminalLeaves(tx);
    final bool allClosed = terminals.isEmpty ? true : terminals.every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    if (!allClosed) {
      throw ValidationException(
        2002,
        "[DELETE RULE 2 FAIL] active child transactions exist tid=${tx.tid}",
        "This transaction cannot be deleted because related transactions are still in progress.",
        silent: !debugLogs,
      );
    }

    final List<TransactionsModel> leaves = await collectAllLeaves (tx);
    final bool allInactive = leaves.isEmpty ? true : leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed || leaf.statusEnum == TransactionStatus.inactive);
    if (!allInactive) {
      throw ValidationException(
        2003,
        "[DELETE RULE 3 FAIL] active child transactions exist tid=${tx.tid}",
        "This transaction cannot be deleted because related transactions are still in progress.",
        silent: !debugLogs,
      );
    }

    return true;
  }

  Future<bool> canUpdate(TransactionsModel tx) async {
    final TransactionsModel? otx = _box.get(tx.tid);
    final TransactionsModel? ptx = _box.get(tx.pid);
    final TransactionsModel? rtx = _box.get(tx.rid);

    if (otx == null) {
      throw ValidationException(
        3001,
        "[UPDATE RULE 1 FAIL] otx == null tid=${tx.tid}",
        "This transaction can no longer be found.",
        silent: !debugLogs,
      );
    }

    if (otx.isRoot && (tx.pid != '0' || tx.rid != '0')) {
      throw ValidationException(
        3002,
        "[UPDATE RULE 2 FAIL] root cannot change pid/rid tid=${tx.tid}",
        "This transaction cannot be changed in that way.",
        silent: !debugLogs,
      );
    }

    if (otx.isLeaf && (ptx == null || rtx == null)) {
      throw ValidationException(
        3003,
        "[UPDATE RULE 3 FAIL] leaf missing parent or root ptx=$ptx rtx=$rtx tid=${tx.tid}",
        "This transaction is not linked correctly.",
        silent: !debugLogs,
      );
    }

    if (tx.rrId <= 0 || tx.srId <= 0 || tx.srAmount <= 0 || tx.rrAmount <= 0 || tx.timestamp <= 0) {
      throw ValidationException(
        3004,
        "[UPDATE RULE 4 FAIL] invalid fields rrId=${tx.rrId} srId=${tx.srId} "
            "srAmount=${tx.srAmount} rrAmount=${tx.rrAmount} timestamp=${tx.timestamp}",
        "Some required transaction details are missing or invalid.",
        silent: !debugLogs,
      );
    }

    final List<TransactionsModel> leaves = await collectTerminalLeaves(tx);
    final targetCloser = await getCloseTargetParent(tx);
    final children = await getLeaf(tx);

    final bool hasChildren = children.isNotEmpty;
    final bool allClosed = leaves.isEmpty ? true : leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed);
    final double spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final double balance = otx.rrAmount - spent;

    if (tx.rrId != otx.rrId || tx.rrAmount != otx.rrAmount || tx.srId != otx.srId || tx.srAmount != otx.srAmount) {
      if (hasChildren) {
        throw ValidationException(
          3005,
          "[UPDATE RULE 5 FAIL] cannot change SR/RR fields when hasChildren=true tid=${tx.tid}",
          "This transaction cannot change its accounts or amounts because related transactions depend on it.",
          silent: !debugLogs,
        );
      }
    }

    if (otx.isLeaf && ptx != null && otx.srAmount != tx.srAmount) {
      if (otx.srAmount < tx.srAmount && ptx.balance < (tx.srAmount - otx.srAmount)) {
        throw ValidationException(
          3006,
          "[UPDATE RULE 5 FAIL] cannot change SR/SR fields when parent has insufficient balance",
          "This transaction cannot change its source amounts because parent has insufficient balance.",
          silent: !debugLogs,
        );
      }  
    }

    if (tx.status != otx.status) {
      switch (tx.statusEnum) {
        case TransactionStatus.inactive:
          if (!hasChildren) {
            throw ValidationException(
              3007,
              "[UPDATE RULE 7A FAIL] inactive requires hasChildren=true tid=${tx.tid}",
              "This transaction cannot be marked inactive.",
              silent: !debugLogs,
            );
          }
          if (balance > 0) {
            throw ValidationException(
              3008,
              "[UPDATE RULE 7A FAIL] inactive requires balance=0 balance=$balance tid=${tx.tid}",
              "This transaction still has remaining balance and cannot be marked inactive.",
              silent: !debugLogs,
            );
          }
          break;

        case TransactionStatus.active:
          if (!hasChildren && tx.balance <= 0) {
            throw ValidationException(
              3009,
              "[UPDATE RULE 7B FAIL] active requires balance>0 when no children tid=${tx.tid}",
              "This transaction must have a positive balance to remain active.",
              silent: !debugLogs,
            );
          }
          if (hasChildren && !allClosed) {
            throw ValidationException(
              3010,
              "[UPDATE RULE 7B FAIL] active requires all children closed tid=${tx.tid}",
              "All related transactions must be completed before this one can be active.",
              silent: !debugLogs,
            );
          }
          break;

        case TransactionStatus.partial:
          if (!hasChildren) {
            throw ValidationException(
              3011,
              "[UPDATE RULE 7C FAIL] partial requires hasChildren=true tid=${tx.tid}",
              "This transaction cannot be marked as partially completed.",
              silent: !debugLogs,
            );
          }
          if (hasChildren && allClosed) {
            throw ValidationException(
              3012,
              "[UPDATE RULE 7C FAIL] partial cannot have all children closed tid=${tx.tid}",
              "This transaction cannot be marked as partial because all related transactions are already completed.",
              silent: !debugLogs,
            );
          }
          break;

        case TransactionStatus.closed:
          if (tx.isRoot) {
            throw ValidationException(
              3013,
              "[UPDATE RULE 7D FAIL] root cannot be closed tid=${tx.tid}",
              "This transaction cannot be closed directly.",
              silent: !debugLogs,
            );
          }
          if (targetCloser == null) {
            throw ValidationException(
              3014,
              "[UPDATE RULE 7D FAIL] closed requires targetCloser!=null tid=${tx.tid}",
              "This transaction is not ready to be closed yet.",
              silent: !debugLogs,
            );
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
            throw ValidationException(
              3015,
              "[UPDATE RULE 8A FAIL] root closable=true requires allClosed=true tid=${tx.tid}",
              "This transaction cannot be marked as closable yet.",
              silent: !debugLogs,
            );
          }
          if (tx.isLeaf && !otx.isActive) {
            throw ValidationException(
              3016,
              "[UPDATE RULE 8A FAIL] leaf closable=true requires otx.active tid=${tx.tid}",
              "This transaction must be active before it can be marked as closable.",
              silent: !debugLogs,
            );
          }
          if (tx.isLeaf && targetCloser == null) {
            throw ValidationException(
              3017,
              "[UPDATE RULE 8A FAIL] leaf closable=true requires targetCloser!=null tid=${tx.tid}",
              "This transaction cannot be marked as closable yet.",
              silent: !debugLogs,
            );
          }
          break;

        case false:
          if (tx.isRoot && allClosed) {
            throw ValidationException(
              3018,
              "[UPDATE RULE 8B FAIL] root closable=false cannot have allClosed=true tid=${tx.tid}",
              "This transaction must remain closable.",
              silent: !debugLogs,
            );
          }
          if (tx.isLeaf && otx.isActive && targetCloser != null) {
            throw ValidationException(
              3019,
              "[UPDATE RULE 8B FAIL] leaf closable=false cannot have active+targetCloser tid=${tx.tid}",
              "This transaction cannot be marked as not closable.",
              silent: !debugLogs,
            );
          }
          break;
      }
    }

    return true;
  }

  Future<bool> canAdd(TransactionsModel tx) async {
    final TransactionsModel? ptx = _box.get(tx.pid);
    final TransactionsModel? rtx = _box.get(tx.rid);

    if (tx.tid == '0') {
      throw ValidationException(
        4001,
        "[ADD RULE 1 FAIL] tid == '0'",
        "This transaction is invalid.",
        silent: !debugLogs,
      );
    }

    if (tx.pid == '0' && tx.rid != '0') {
      throw ValidationException(
        4002,
        "[ADD RULE 2 FAIL] pid=0 but rid!=0 pid=${tx.pid} rid=${tx.rid}",
        "This transaction is not linked correctly.",
        silent: !debugLogs,
      );
    }

    if (tx.rid == '0' && tx.pid != '0') {
      throw ValidationException(
        4003,
        "[ADD RULE 3 FAIL] rid=0 but pid!=0 pid=${tx.pid} rid=${tx.rid}",
        "This transaction is not linked correctly.",
        silent: !debugLogs,
      );
    }

    if (tx.rrId <= 0 || tx.srId <= 0 || tx.srAmount <= 0 || tx.rrAmount <= 0 || tx.timestamp <= 0) {
      throw ValidationException(
        4004,
        "[ADD RULE 4 FAIL] invalid fields rrId=${tx.rrId} srId=${tx.srId} "
            "srAmount=${tx.srAmount} rrAmount=${tx.rrAmount} timestamp=${tx.timestamp}",
        "Some required transaction details are missing or invalid.",
        silent: !debugLogs,
      );
    }

    if (tx.statusEnum != TransactionStatus.active) {
      throw ValidationException(
        4005,
        "[ADD RULE 5 FAIL] status must be active status=${tx.statusEnum}",
        "A new transaction must start as active.",
        silent: !debugLogs,
      );
    }

    if (tx.isRoot) {
      if (tx.balance != tx.rrAmount) {
        throw ValidationException(
          4006,
          "[ADD RULE 6 FAIL] root balance mismatch balance=${tx.balance} rrAmount=${tx.rrAmount}",
          "The transaction balance does not match the expected amount.",
          silent: !debugLogs,
        );
      }

      if (tx.closable != true) {
        throw ValidationException(
          4007,
          "[ADD RULE 7 FAIL] root must be closable=true",
          "This transaction must be marked as closable.",
          silent: !debugLogs,
        );
      }
    }

    if (tx.isLeaf) {
      final targetCloser = await getCloseTargetParent(tx);

      if (rtx == null) {
        throw ValidationException(
          4008,
          "[ADD RULE 8 FAIL] rtx == null rid=${tx.rid}",
          "This transaction is not linked correctly.",
          silent: !debugLogs,
        );
      }

      if (ptx == null) {
        throw ValidationException(
          4009,
          "[ADD RULE 9 FAIL] ptx == null pid=${tx.pid}",
          "This transaction is not linked correctly.",
          silent: !debugLogs,
        );
      }

      if (tx.srId != ptx.rrId) {
        throw ValidationException(
          4010,
          "[ADD RULE 10 FAIL] srId=${tx.srId} != parent.rrId=${ptx.rrId}",
          "This transaction does not match the expected account.",
          silent: !debugLogs,
        );
      }

      if (tx.srAmount > ptx.balance) {
        throw ValidationException(
          4011,
          "[ADD RULE 11 FAIL] srAmount=${tx.srAmount} > parent.balance=${ptx.balance}",
          "The transaction amount exceeds the available balance.",
          silent: !debugLogs,
        );
      }

      if (tx.closable == true && targetCloser == null) {
        throw ValidationException(
          4012,
          "[ADD RULE 12 FAIL] closable=true but targetCloser == null",
          "This transaction cannot be marked as closable yet.",
          silent: !debugLogs,
        );
      }

      if (tx.closable == false && targetCloser != null) {
        throw ValidationException(
          40113,
          "[ADD RULE 13 FAIL] closable=false but targetCloser exists",
          "This transaction must be marked as closable.",
          silent: !debugLogs,
        );
      }
    }

    return true;
  }

  Future<bool> canClose(TransactionsModel tx) async {
    // Cannot check for existing tx as it will break at add method.
    if (tx.isRoot) {
      throw ValidationException(
        5001,
        "[CLOSE RULE 1 FAIL] otx.isRoot == true tid=${tx.tid}",
        "This transaction cannot be closed directly.",
        silent: !debugLogs,
      );
    }

    if (!tx.isActive) {
      throw ValidationException(
        5003,
        "[CLOSE RULE 2 FAIL] otx.isActive == false tid=${tx.tid}",
        "An inactive transaction cannot be closed.",
        silent: !debugLogs,
      );
    }

    final targetCloser = await getCloseTargetParent(tx);

    if (targetCloser == null) {
      throw ValidationException(
        5004,
        "[CLOSE RULE 3 FAIL] targetCloser == null tid=${tx.tid}",
        "This transaction is not ready to be closed yet.",
        silent: !debugLogs,
      );
    }

    return true;
  }

  Future<bool> canTrade(TransactionsModel tx) async {
    if (tx.tid == '0') {
      throw ValidationException(
        6001,
        "[TRADE RULE 1 FAIL] tx.tid == '0'",
        "This trade cannot be processed because its ID is invalid.",
        silent: !debugLogs,
      );
    }

    final TransactionsModel? otx = _box.get(tx.tid);

    if (otx == null) {
      throw ValidationException(
        6002,
        "[TRADE RULE 2 FAIL] otx == null tid=${tx.tid}",
        "This trade cannot be processed because the original transaction was not found.",
        silent: !debugLogs,
      );
    }

    if (!otx.isRoot) {
      final TransactionsModel? ptx = _box.get(tx.pid);
      final TransactionsModel? rtx = _box.get(tx.rid);

      if (ptx == null || rtx == null) {
        throw ValidationException(
          6003,
          "[TRADE RULE 3 FAIL] ptx == null or rtx == null tid=${tx.tid}",
          "Invalid transaction cannot be traded.",
          silent: !debugLogs,
        );
      }
    }

    if (!otx.isActive && !otx.isPartial) {
      throw ValidationException(
        6004,
        "[TRADE RULE 4 FAIL] not active or not partial "
            "isActive=${otx.isActive} isPartial=${otx.isPartial} tid=${tx.tid}",
        "This trade cannot be processed because the original transaction is not in a valid state.",
        silent: !debugLogs,
      );
    }

    if (otx.rrId <= 0 || otx.srId <= 0 || otx.srAmount <= 0 || otx.rrAmount <= 0 || otx.timestamp <= 0) {
      throw ValidationException(
        6005,
        "[TRADE RULE 5 FAIL] invalid required fields "
            "rrId=${otx.rrId} srId=${otx.srId} srAmount=${otx.srAmount} "
            "rrAmount=${otx.rrAmount} timestamp=${otx.timestamp}",
        "Some required trade details are missing or invalid.",
        silent: !debugLogs,
      );
    }

    if (otx.balance <= 0) {
      throw ValidationException(
        6006,
        "[TRADE RULE 6 FAIL] balance <= 0 balance=${otx.balance} "
            "rrId=${otx.rrId} srId=${otx.srId}",
        "This trade cannot be processed because the remaining balance is invalid.",
        silent: !debugLogs,
      );
    }

    return true;
  }

  Future<double> getCapitalBalance(TransactionsModel tx) async {
    final children = await getLeaf(tx);
    final double spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final double balance = tx.rrAmount - spent;

    return balance;
  }

  Future<void> _deleteLeaves(TransactionsModel tx) async {
    final all = await getAll();
    for (final ttx in all) {
      if (tx.tid == ttx.rid || tx.tid == ttx.pid) {
        if (debugLogs) {
          logln(
            '[DELETE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
          );
        }

        _box.delete(ttx.tid);
      }
    }
  }
}