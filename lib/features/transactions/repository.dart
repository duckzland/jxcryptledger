import 'dart:math';

import 'package:hive_ce/hive_ce.dart';

import '../../app/exceptions.dart';
import '../../core/filtering.dart';
import '../../core/log.dart';
import 'model.dart';
import 'rules/close.dart';
import 'rules/create.dart';
import 'rules/delete.dart';
import 'rules/trade.dart';
import 'rules/update.dart';

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
      final randomPart = String.fromCharCodes(Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

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

  Future<TransactionsModel?> get(String tid) async {
    return _box.get(tid);
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

  Future<double> getCapitalBalance(TransactionsModel tx) async {
    final children = await getLeaf(tx);
    final double spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final double balance = tx.rrAmount - spent;

    return balance;
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

  Future<bool> canAdd(TransactionsModel tx) async {
    final rules = TransactionsRulesCreate(tx, this, !debugLogs);
    final isValid = await rules.validate();
    return isValid;
  }

  Future<bool> canDelete(TransactionsModel tx) async {
    final rules = TransactionsRulesDelete(tx, this, !debugLogs);
    final isValid = await rules.validate();
    return isValid;
  }

  Future<bool> canUpdate(TransactionsModel tx) async {
    final rules = TransactionsRulesUpdate(tx, this, !debugLogs);
    final isValid = await rules.validate();
    return isValid;
  }

  Future<bool> canClose(TransactionsModel tx) async {
    final rules = TransactionsRulesClose(tx, this, !debugLogs);
    final isValid = await rules.validate();
    return isValid;
  }

  Future<bool> canTrade(TransactionsModel tx) async {
    final rules = TransactionsRulesTrade(tx, this, !debugLogs);
    final isValid = await rules.validate();
    return isValid;
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
