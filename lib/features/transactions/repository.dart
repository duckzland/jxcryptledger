import 'package:hive_ce/hive_ce.dart';

import '../../core/abstracts/repository.dart';
import '../../core/filtering.dart';
import '../../core/log.dart';
import '../../core/mixins/exportable.dart';
import '../../core/mixins/id_generator.dart';
import 'model.dart';
import 'rules/close.dart';
import 'rules/create.dart';
import 'rules/delete.dart';
import 'rules/import.dart';
import 'rules/refund.dart';
import 'rules/trade.dart';
import 'rules/update.dart';

class TransactionsRepository extends CoreBaseRepository<TransactionsModel, String>
    with CoreMixinsIdGenerator<TransactionsModel, String>, CoreMixinsExportable<TransactionsModel, String> {
  @override
  String get boxName => 'transactions_box';

  @override
  get fromJson => TransactionsModel.fromJson;

  final bool debugLogs = true;

  final FilterIsolate _filter = FilterIsolate();

  Future<void> init() async {
    await _filter.init();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<TransactionsModel>(boxName);
    }
  }

  @override
  Future<void> add(TransactionsModel tx) async {
    if (debugLogs) {
      logln(
        '[ADD] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    TransactionsModel ntx = tx;

    bool isClosable;
    try {
      isClosable = canClose(ntx);
    } catch (e) {
      isClosable = false;
    }

    if (tx.isClosable != isClosable) {
      ntx = ntx.copyWith(closable: isClosable);
    }

    canAdd(ntx);

    if (ntx.isRoot) {
      await box.put(ntx.tid, ntx);
      return;
    }

    if (ntx.isLeaf) {
      TransactionsModel? ptx = box.get(ntx.pid)!;
      canTrade(ptx);

      // Update the parent balance and status
      // This is important to preserve valid tree structure!
      final balance = ptx.balance - ntx.srAmount;
      final nptx = ptx.copyWith(
        balance: balance,
        status: balance <= 0 ? TransactionStatus.inactive.index : TransactionStatus.partial.index,
      );

      logln("[ADD] Rebalancing amount ${ptx.balance}|${ntx.srAmount}|${ptx.rrId}|${ntx.srId}");

      await box.put(ntx.tid, ntx);

      // Force to revalidate!
      await update(nptx);
      return;
    }
  }

  @override
  Future<void> update(TransactionsModel tx) async {
    if (debugLogs) {
      logln(
        '[UPDATE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    TransactionsModel ntx = tx;
    bool isClosable;
    try {
      isClosable = canClose(ntx);
    } catch (e) {
      isClosable = false;
    }

    if (tx.isClosable != isClosable) {
      ntx = ntx.copyWith(closable: isClosable);
    }

    canUpdate(ntx);

    if (ntx.isRoot) {
      await box.put(ntx.tid, ntx);
      return;
    }

    // Update the parent balance and status
    // This is important to preserve valid tree structure!
    if (tx.isLeaf) {
      TransactionsModel? ptx = box.get(ntx.pid)!;
      TransactionsModel? otx = box.get(ntx.tid)!;

      await box.put(ntx.tid, ntx);

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

  @override
  Future<void> delete(TransactionsModel tx) async {
    canDelete(tx);

    if (debugLogs) {
      logln(
        '[DELETE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    // This is to preseve tree sanity!
    final all = getAll();
    for (final ttx in all) {
      if (tx.tid == ttx.rid || tx.tid == ttx.pid) {
        if (debugLogs) {
          logln(
            '[DELETE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
          );
        }

        box.delete(ttx.tid);
      }
    }

    await box.delete(tx.tid);
  }

  Future<void> close(TransactionsModel tx) async {
    canClose(tx);

    // canClose already check and throw
    TransactionsModel? otx = box.get(tx.tid);
    if (otx == null) {
      return;
    }

    // canClose already check and throw
    TransactionsModel? target = getCloseTargetParent(otx);
    if (target == null) {
      return;
    }

    final leaves = collectTerminalLeaves(target);
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

    await box.put(closedTx.tid, closedTx);
    await box.put(updatedTarget.tid, updatedTarget);
  }

  Future<void> refund(TransactionsModel tx) async {
    canRefund(tx);

    // canClose already check and throw
    TransactionsModel? otx = box.get(tx.tid);
    TransactionsModel? ptx = box.get(tx.pid);
    if (otx == null || ptx == null) {
      return;
    }

    final leaves = collectTerminalLeaves(ptx);
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

    await box.delete(tx.tid);
    await box.put(updatedTarget.tid, updatedTarget);
  }

  @override
  Future<void> import(String rawJson) async {
    final rule = TransactionsRulesImport();
    final txs = rule.validateJson(rawJson);
    await box.clear();
    for (final tx in txs) {
      await box.put(tx.tid, tx);
    }
  }

  List<TransactionsModel> getLeaf(TransactionsModel tx) {
    final list = <TransactionsModel>[];
    for (final key in box.keys) {
      final ltx = box.get(key);
      if (ltx != null && ltx.pid == tx.tid) list.add(ltx);
    }
    return list;
  }

  TransactionsModel? getCloseTargetParent(TransactionsModel tx) {
    if (tx.isRoot) {
      return null;
    }

    final all = getAll();

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

  double getCapitalBalance(TransactionsModel tx) {
    final children = getLeaf(tx);
    final double spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final double balance = tx.rrAmount - spent;

    return balance;
  }

  Future<List<TransactionsModel>> filter(String query) async {
    final all = getAll();
    final maps = all.map((e) => e.toMap()).toList();

    final filteredMaps = await _filter.filter(maps, query);
    return filteredMaps.map(TransactionsModel.fromMap).toList();
  }

  List<TransactionsModel> collectAllRoots() {
    final all = getAll();
    return all.where((tx) => tx.isRoot).toList();
  }

  List<TransactionsModel> collectAllTerminalLeaves() {
    final all = getAll();
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

  List<TransactionsModel> collectTerminalLeaves(TransactionsModel parent) {
    final all = getAll();

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

  List<TransactionsModel> collectAllRootLeaves(TransactionsModel parent) {
    final all = getAll();

    final leaves = <TransactionsModel>[];
    for (final tx in all) {
      if (tx.rid == parent.tid) {
        leaves.add(tx);
      }
    }

    return leaves;
  }

  List<TransactionsModel> collectAllLeaves(TransactionsModel parent) {
    final all = getAll();

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

  List<TransactionsModel> collectDescendantLeaves(TransactionsModel parent) {
    final all = getAll();

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

  bool canAdd(TransactionsModel tx, {bool? silent}) {
    final rules = TransactionsRulesCreate(tx, this, silent ?? !debugLogs);
    final isValid = rules.validate();
    return isValid;
  }

  bool canDelete(TransactionsModel tx, {bool? silent}) {
    final rules = TransactionsRulesDelete(tx, this, silent ?? !debugLogs);
    final isValid = rules.validate();
    return isValid;
  }

  bool canUpdate(TransactionsModel tx, {bool? silent = false}) {
    final rules = TransactionsRulesUpdate(tx, this, silent ?? !debugLogs);
    final isValid = rules.validate();
    return isValid;
  }

  bool canClose(TransactionsModel tx, {bool? silent = false}) {
    final rules = TransactionsRulesClose(tx, this, silent ?? !debugLogs);
    final isValid = rules.validate();
    return isValid;
  }

  bool canTrade(TransactionsModel tx, {bool? silent}) {
    final rules = TransactionsRulesTrade(tx, this, silent ?? !debugLogs);
    final isValid = rules.validate();
    return isValid;
  }

  bool canRefund(TransactionsModel tx, {bool? silent}) {
    final rules = TransactionsRulesRefund(tx, this, silent ?? !debugLogs);
    final isValid = rules.validate();
    return isValid;
  }
}
