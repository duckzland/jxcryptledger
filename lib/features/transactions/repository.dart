import 'dart:convert';
import 'dart:math';

import 'package:hive_ce/hive_ce.dart';

import '../../app/exceptions.dart';
import '../../core/filtering.dart';
import '../../core/log.dart';
import 'model.dart';
import 'rules/close.dart';
import 'rules/create.dart';
import 'rules/delete.dart';
import 'rules/refund.dart';
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

    if (ntx.isRoot) {
      await _box.put(ntx.tid, ntx);
      return;
    }

    if (ntx.isLeaf) {
      TransactionsModel? ptx = _box.get(ntx.pid)!;
      await canTrade(ptx);

      // Update the parent balance and status
      // This is important to preserve valid tree structure!
      final balance = ptx.balance - ntx.srAmount;
      final nptx = ptx.copyWith(
        balance: balance,
        status: balance <= 0 ? TransactionStatus.inactive.index : TransactionStatus.partial.index,
      );

      logln("[ADD] Rebalancing amount ${ptx.balance}|${ntx.srAmount}|${ptx.rrId}|${ntx.srId}");

      await _box.put(ntx.tid, ntx);

      // Force to revalidate!
      await update(nptx);
      return;
    }
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

    if (ntx.isRoot) {
      await _box.put(ntx.tid, ntx);
      return;
    }

    // Update the parent balance and status
    // This is important to preserve valid tree structure!
    if (tx.isLeaf) {
      TransactionsModel? ptx = _box.get(ntx.pid)!;
      TransactionsModel? otx = _box.get(ntx.tid)!;

      await _box.put(ntx.tid, ntx);

      if (otx.srAmount != tx.srAmount && ptx.rrId == otx.srId) {
        double balance = ptx.balance;
        if (otx.srAmount > tx.srAmount) {
          balance += otx.srAmount - tx.srAmount;
        } else {
          double spent = tx.srAmount - otx.srAmount;
          if (balance >= spent) {
            balance -= spent;
          }
        }

        logln("[UPDATE] Rebalancing amount ${otx.srAmount}|${tx.srAmount}|${ptx.rrId}|${otx.srId}|${tx.balance}|${otx.balance}|$balance");

        final nptx = ptx.copyWith(
          balance: balance,
          status: balance > 0 ? TransactionStatus.partial.index : TransactionStatus.inactive.index,
        );

        // Force to revalidate!
        await update(nptx);
      }
    }
  }

  Future<void> delete(TransactionsModel tx) async {
    await canDelete(tx);

    if (debugLogs) {
      logln(
        '[DELETE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    // This is to preseve tree sanity!
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

    await _box.delete(tx.tid);
  }

  Future<void> close(TransactionsModel tx) async {
    await canClose(tx);

    // canClose already check and throw
    TransactionsModel? otx = _box.get(tx.tid);
    if (otx == null) {
      return;
    }

    // canClose already check and throw
    TransactionsModel? target = await getCloseTargetParent(otx);
    if (target == null) {
      return;
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

  Future<void> refund(TransactionsModel tx) async {
    await canRefund(tx);

    // canClose already check and throw
    TransactionsModel? otx = _box.get(tx.tid);
    TransactionsModel? ptx = _box.get(tx.pid);
    if (otx == null || ptx == null) {
      return;
    }

    final leaves = await collectTerminalLeaves(ptx);
    final allClosed =
        leaves.isNotEmpty &&
        leaves
            // Current tx hasn't mutate status yet thus ignore it!
            .where((leaf) => leaf.tid != otx.tid)
            .every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    final newStatus = allClosed ? TransactionStatus.active.index : TransactionStatus.partial.index;
    final updatedTarget = ptx.copyWith(balance: ptx.balance + tx.srAmount, status: newStatus);

    if (debugLogs) {
      logln(
        '[REFUNDING] ${tx.tid}|${tx.pid}|${tx.rid}|{tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    await _box.delete(tx.tid);
    await _box.put(updatedTarget.tid, updatedTarget);
  }

  Future<String> export() async {
    final items = _box.values.toList();
    final jsonList = items.map((tx) => tx.toJson()).toList();
    return jsonEncode(jsonList);
  }

  Future<void> import(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw ValidationException(AppErrorCode.txImportInvalidJSON, "Invalid JSON format", "Import failed");
    }

    final tids = <String>{};
    final List<TransactionsModel> txs = [];

    for (final item in decoded) {
      final tx = TransactionsModel.fromJson(item);
      txs.add(tx);
    }

    for (final tx in txs) {
      if (!tids.add(tx.tid)) {
        throw ValidationException(AppErrorCode.txImportDuplicateTid, "Duplicate TID detected: ${tx.tid}", "Import failed");
      }
    }

    final map = {for (final t in txs) t.tid: t};

    for (final tx in txs) {
      if (tx.pid.isNotEmpty && tx.pid != '0' && !map.containsKey(tx.pid)) {
        throw ValidationException(AppErrorCode.txImportInvalidParent, "Invalid parent: ${tx.pid} for ${tx.tid}", "Import failed");
      }

      if (tx.rid.isNotEmpty && tx.rid != '0' && !map.containsKey(tx.rid)) {
        throw ValidationException(AppErrorCode.txImportInvalidRid, "Invalid rid: ${tx.rid} for ${tx.tid}", "Import failed");
      }

      if (!tx.isRoot && !tx.isLeaf) {
        throw ValidationException(AppErrorCode.txImportInvalidRootStructure, "Invalid root structure for ${tx.tid}", "Import failed");
      }

      if (tx.isLeaf) {
        final parent = map[tx.pid]!;
        if (tx.srId != parent.rrId) {
          throw ValidationException(AppErrorCode.txImportSrIdMismatch, "srId mismatch for ${tx.tid}", "Import failed");
        }
        if (tx.srAmount > parent.rrAmount) {
          throw ValidationException(
            AppErrorCode.txImportSrAmountExceedsParent,
            "srAmount exceeds parent rrAmount for ${tx.tid}",
            "Import failed",
          );
        }
      }
    }

    final children = <String, List<TransactionsModel>>{};
    for (final tx in txs) {
      if (tx.pid.isNotEmpty) {
        children.putIfAbsent(tx.pid, () => []).add(tx);
      }
    }

    for (final tx in txs) {
      final list = children[tx.tid] ?? [];
      if (list.isNotEmpty) {
        final sum = list.fold<double>(0, (a, b) => a + b.srAmount);
        if (sum > tx.rrAmount) {
          throw ValidationException(
            AppErrorCode.txImportChildAmountSumExceeded,
            "Child srAmount sum exceeds parent rrAmount for ${tx.tid}",
            "Import failed",
          );
        }
      }
    }

    for (final tx in txs) {
      final list = children[tx.tid] ?? [];

      if (tx.balance == 0) {
        if (tx.status != TransactionStatus.inactive.index) {
          throw ValidationException(
            AppErrorCode.txImportZeroBalanceNotInactive,
            "Zero balance must be inactive for ${tx.tid}",
            "Import failed",
          );
        }
        continue;
      }

      final hasActiveChild = list.any((c) => c.status == TransactionStatus.active.index);

      if (tx.balance > 0) {
        if (hasActiveChild) {
          if (tx.status != TransactionStatus.partial.index) {
            throw ValidationException(
              AppErrorCode.txImportNonZeroBalanceNotPartial,
              "Non-zero balance with active children must be partial for ${tx.tid}",
              "Import failed",
            );
          }
        } else {
          if (tx.status != TransactionStatus.active.index) {
            throw ValidationException(
              AppErrorCode.txImportNonZeroBalanceNotActive,
              "Non-zero balance without active children must be active for ${tx.tid}",
              "Import failed",
            );
          }
        }
      }
    }

    for (final tx in txs) {
      if (tx.isRoot) continue;
      TransactionsModel? ancestor = tx;
      bool closable = false;

      while (ancestor != null && ancestor.pid != '0') {
        final p = map[ancestor.pid];
        if (p == null) break;

        if (p.rrId == tx.rrId) {
          closable = true;
          break;
        }

        ancestor = p;
      }

      if (tx.closable != closable) {
        throw ValidationException(AppErrorCode.txImportInvalidClosableState, "Invalid closable state for ${tx.tid}", "Import failed");
      }
    }

    await _box.clear();
    for (final tx in txs) {
      await _box.put(tx.tid, tx);
    }
  }

  Future<int> clear() async {
    return await _box.clear();
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

  Future<List<TransactionsModel>> collectAllRoots() async {
    final all = await getAll();
    return all.where((tx) => tx.isRoot).toList();
  }

  Future<List<TransactionsModel>> collectAllTerminalLeaves() async {
    final all = await getAll();
    final Map<String, int> childCount = {};
    for (final tx in all) {
      childCount[tx.pid] = (childCount[tx.pid] ?? 0) + 1;
    }

    bool isTerminalLeaf(TransactionsModel tx) {
      final hasChildren = (childCount[tx.tid] ?? 0) > 0;
      return !hasChildren && !tx.isRoot;
    }

    return all.where(isTerminalLeaf).toList();
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

  Future<List<TransactionsModel>> collectAllRootLeaves(TransactionsModel parent) async {
    final all = await getAll();

    final leaves = <TransactionsModel>[];
    for (final tx in all) {
      if (tx.rid == parent.tid) {
        leaves.add(tx);
      }
    }

    return leaves;
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

  Future<List<TransactionsModel>> collectDescendantLeaves(TransactionsModel parent) async {
    final all = await getAll();

    final Map<String, List<TransactionsModel>> childrenMap = {};
    for (final tx in all) {
      childrenMap.putIfAbsent(tx.pid, () => []).add(tx);
    }

    List<TransactionsModel> dfs(TransactionsModel node) {
      final children = childrenMap[node.tid] ?? [];
      final descendants = <TransactionsModel>[];

      for (final child in children) {
        descendants.add(child);
        descendants.addAll(dfs(child));
      }

      return descendants;
    }

    return dfs(parent);
  }

  Future<bool> canAdd(TransactionsModel tx, {bool? silent}) async {
    final rules = TransactionsRulesCreate(tx, this, silent ?? !debugLogs);
    final isValid = await rules.validate();
    return isValid;
  }

  Future<bool> canDelete(TransactionsModel tx, {bool? silent}) async {
    final rules = TransactionsRulesDelete(tx, this, silent ?? !debugLogs);
    final isValid = await rules.validate();
    return isValid;
  }

  Future<bool> canUpdate(TransactionsModel tx, {bool? silent = false}) async {
    final rules = TransactionsRulesUpdate(tx, this, silent ?? !debugLogs);
    final isValid = await rules.validate();
    return isValid;
  }

  Future<bool> canClose(TransactionsModel tx, {bool? silent = false}) async {
    final rules = TransactionsRulesClose(tx, this, silent ?? !debugLogs);
    final isValid = await rules.validate();
    return isValid;
  }

  Future<bool> canTrade(TransactionsModel tx, {bool? silent}) async {
    final rules = TransactionsRulesTrade(tx, this, silent ?? !debugLogs);
    final isValid = await rules.validate();
    return isValid;
  }

  Future<bool> canRefund(TransactionsModel tx, {bool? silent}) async {
    final rules = TransactionsRulesRefund(tx, this, silent ?? !debugLogs);
    final isValid = await rules.validate();
    return isValid;
  }

  bool isEmpty() {
    return _box.isEmpty;
  }
}
