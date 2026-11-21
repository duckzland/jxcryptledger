import 'package:decimal/decimal.dart' show Decimal;

import '../../core/mixins/repositories/exportable.dart';
import '../../core/mixins/repositories/id_generator.dart';
import '../../core/abstracts/repository.dart';
import '../../core/log.dart';
import '../../core/math.dart';
import 'rules/close.dart';
import 'rules/create.dart';
import 'rules/delete.dart';
import 'rules/finalize.dart';
import 'rules/import.dart';
import 'rules/refund.dart';
import 'rules/trade.dart';
import 'rules/update.dart';
import 'model.dart';

class TransactionsRepository extends CoreBaseRepository<TransactionsModel>
    with CoreMixinsRepositoriesIdGenerator<TransactionsModel>, CoreMixinsRepositoriesExportable<TransactionsModel> {
  String boxNameDefault = 'transactions_box';

  @override
  String get boxName => boxNameDefault;

  @override
  get fromJson => TransactionsModel.fromJson;

  final bool debugLogs = true;

  Map<String, TransactionsModel>? _indexByTid;
  Map<String, List<TransactionsModel>>? _indexByPid;
  Map<String, Map<String, TransactionsModel>>? _indexByRid;

  void resetIndexes() {
    _indexByTid = null;
    _indexByPid = null;
    _indexByRid = null;
  }

  void createIndexes() {
    final indexed = <String, TransactionsModel>{};
    final roots = <String, Map<String, TransactionsModel>>{};
    final children = <String, List<TransactionsModel>>{};

    for (final tx in extract()) {
      indexed[tx.tid] = tx;
      (roots[tx.isRoot ? tx.tid : tx.rid] ??= <String, TransactionsModel>{})[tx.tid] = tx;
      (children[tx.pid] ??= <TransactionsModel>[]).add(tx);
    }

    _indexByTid = indexed;
    _indexByPid = children;
    _indexByRid = roots;

    logln("Generating tx indexes", "INDEXING");
  }

  @override
  void onAction() {
    resetIndexes();
  }

  @override
  void receive(event) {
    super.receive(event);
    resetIndexes();
  }

  Map<String, TransactionsModel> getIndexedMap() {
    if (_indexByTid == null) {
      createIndexes();
    }
    return _indexByTid!;
  }

  Map<String, List<TransactionsModel>> getIndexedParentMap() {
    if (_indexByPid == null) {
      createIndexes();
    }
    return _indexByPid!;
  }

  Map<String, Map<String, TransactionsModel>> getIndexedRootMap() {
    if (_indexByRid == null) {
      createIndexes();
    }
    return _indexByRid!;
  }

  @override
  Future<void> add(TransactionsModel tx) async {
    if (debugLogs) {
      logln(
        "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
        "ADD",
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
      resetIndexes();
      return;
    }

    if (ntx.isLeaf) {
      TransactionsModel? ptx = box.get(ntx.pid)!;
      canTrade(ptx);

      // Double check if parent can be updated!
      canUpdate(ptx);

      // Update the parent balance and status
      // This is important to preserve valid tree structure!
      final balance = Math.subtract(ptx.balance, ntx.srAmount);
      final nptx = ptx.copyWith(
        balance: balance,
        status: balance <= Decimal.zero ? TransactionStatus.inactive.index : TransactionStatus.partial.index,
      );

      logln("Rebalancing amount $balance|${ptx.balance}|${ntx.srAmount}|${ptx.rrId}|${ntx.srId}", "ADD");
      await box.put(ntx.tid, ntx);
      resetIndexes();

      // Force to revalidate!
      await update(nptx);
    }
  }

  @override
  Future<void> update(TransactionsModel tx) async {
    if (debugLogs) {
      logln(
        "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
        "UPDATE",
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
      resetIndexes();
      return;
    }

    // Update the parent balance and status
    // This is important to preserve valid tree structure!
    if (tx.isLeaf) {
      TransactionsModel? ptx = box.get(ntx.pid)!;
      TransactionsModel? otx = box.get(ntx.tid)!;

      await box.put(ntx.tid, ntx);
      resetIndexes();

      if (otx.srAmount != tx.srAmount && ptx.rrId == otx.srId) {
        Decimal balance = ptx.balance;
        if (otx.srAmount > tx.srAmount) {
          balance = Math.add(balance, Math.subtract(otx.srAmount, tx.srAmount));
        } else {
          Decimal spent = Math.subtract(tx.srAmount, otx.srAmount);
          if (balance >= spent) {
            balance = Math.subtract(balance, spent);
          }
        }

        logln("Rebalancing amount ${otx.srAmount}|${tx.srAmount}|${ptx.rrId}|${otx.srId}|${tx.balance}|${otx.balance}|$balance", "UPDATE");
        final nptx = ptx.copyWith(
          balance: balance,
          status: balance > Decimal.zero ? TransactionStatus.partial.index : TransactionStatus.inactive.index,
        );

        // Force to revalidate!
        await update(nptx);
      }
    }
  }

  @override
  Future<void> remove(TransactionsModel tx) async {
    canDelete(tx);

    if (debugLogs) {
      logln(
        "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
        "DELETE",
      );
    }

    // This is to preseve tree sanity!
    final all = extract();
    for (final ttx in all) {
      if (tx.tid == ttx.rid || tx.tid == ttx.pid) {
        if (debugLogs) {
          logln(
            "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
            "DELETE",
          );
        }

        await box.delete(ttx.tid);
        resetIndexes();
      }
    }

    await box.delete(tx.tid);
    resetIndexes();
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
    bool allClosed = false;
    List<TransactionsModel> leaves = [];

    if (target == null) {
      return;
    }

    // Try terminal leaves first.
    leaves = collectTerminalLeaves(target);
    allClosed =
        leaves.isNotEmpty &&
        leaves
            // Current tx hasn't mutate status yet thus ignore it!
            .where((leaf) => leaf.tid != otx.tid)
            .every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    // if all terminal leaves are closed, double check current branch is all inactive
    if (allClosed) {
      leaves = collectInBetweenLeaves(otx, target);
      allClosed =
          leaves.isNotEmpty &&
          leaves
              // Ignore current otx and its target
              .where((leaf) => leaf.tid != otx.tid)
              .where((leaf) => leaf.tid != target.tid)
              .every((leaf) => leaf.statusEnum == TransactionStatus.inactive);
    }

    final newStatus = allClosed ? TransactionStatus.active.index : TransactionStatus.partial.index;
    final updatedTarget = target.copyWith(balance: Math.add(target.balance, tx.balance), status: newStatus);

    final closedTx = tx.copyWith(balance: Decimal.zero, status: TransactionStatus.closed.index);

    if (debugLogs) {
      logln(
        "${tx.tid}|${tx.pid}|${tx.rid}|{tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
        "CLOSING",
      );
    }

    await box.put(closedTx.tid, closedTx);
    await box.put(updatedTarget.tid, updatedTarget);
    resetIndexes();
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
    final utx = ptx.copyWith(balance: Math.add(ptx.balance, tx.srAmount), status: newStatus);

    if (debugLogs) {
      logln(
        "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
        "REFUNDING",
      );
      logln(
        "${utx.tid}|${utx.pid}|${utx.rid}|${utx.srId}|${utx.srAmount}|${utx.rrId}|${utx.rrAmount}|${utx.balance}|${utx.status}|${utx.closable}|${utx.timestamp}",
        "REBALANCING",
      );
    }

    await box.delete(tx.tid);
    await box.put(utx.tid, utx);
    resetIndexes();
  }

  Future<void> finalize(TransactionsModel tx) async {
    canFinalize(tx);

    if (tx.statusEnum != TransactionStatus.finalized) {
      tx = tx.copyWith(status: TransactionStatus.finalized.index);
    }

    if (debugLogs) {
      logln(
        "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
        "FINALIZING",
      );
    }

    await box.put(tx.tid, tx);
    resetIndexes();
  }

  @override
  Future<void> import(String rawJson) async {
    final rule = TransactionsRulesImport();
    final txs = rule.validateJson(rawJson);
    await box.clear();
    for (final tx in txs) {
      await box.put(tx.tid, tx);
    }
    resetIndexes();
  }

  List<TransactionsModel> getLeaf(TransactionsModel tx) {
    return getIndexedParentMap()[tx.tid] ?? const <TransactionsModel>[];
  }

  TransactionsModel? getCloseTargetParent(TransactionsModel tx) {
    if (tx.isRoot) {
      return null;
    }

    final byTid = getIndexedMap();

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
      final root = byTid[tx.rid];
      if (root != null && root.isRoot) {
        if (root.rrId == tx.rrId) {
          parent = root;
        }
      }
    }

    return parent;
  }

  Decimal getCapitalBalance(TransactionsModel tx) {
    final children = getLeaf(tx);
    final Decimal spent = children.fold<Decimal>(Decimal.zero, (sum, leaf) => Math.add(sum, leaf.srAmount));
    final Decimal balance = Math.subtract(tx.rrAmount, spent);
    return balance;
  }

  List<TransactionsModel> collectAllRoots() {
    final roots = <TransactionsModel>[];
    for (final entry in getIndexedRootMap().entries) {
      final root = entry.value[entry.key];
      if (root != null && root.isRoot) roots.add(root);
    }
    return roots;
  }

  List<TransactionsModel> collectAllTerminalLeaves() {
    final children = getIndexedParentMap();
    return [
      for (final tx in getIndexedMap().values)
        if (!tx.isRoot && (children[tx.tid]?.isEmpty ?? true)) tx,
    ];
  }

  List<TransactionsModel> collectTerminalLeaves(TransactionsModel parent) {
    final childrenMap = getIndexedParentMap();

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

  List<TransactionsModel> collectRootTreeLeaves(TransactionsModel parent) {
    final rootTree = getIndexedRootMap()[parent.tid]?.values;
    return rootTree?.where((tx) => !tx.isRoot).toList() ?? const <TransactionsModel>[];
  }

  List<TransactionsModel> collectDirectLeaves(TransactionsModel parent) {
    final childrenMap = getIndexedParentMap();

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

  List<TransactionsModel> collectAllLeaves(TransactionsModel parent) {
    final childrenMap = getIndexedParentMap();

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

  List<TransactionsModel> collectInBetweenLeaves(TransactionsModel start, TransactionsModel end) {
    final all = extract();

    final Map<String, TransactionsModel> lookup = {for (final tx in all) tx.tid: tx};

    final ascendants = <TransactionsModel>[];
    TransactionsModel? current = start;

    while (current != null && !current.isRoot) {
      final parent = lookup[current.pid];
      if (parent == null) break;
      ascendants.add(parent);

      if (parent.tid == end.tid) break;

      current = parent;
    }

    return ascendants;
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

  bool canFinalize(TransactionsModel tx, {bool? silent}) {
    final rules = TransactionsRulesFinalize(tx, this, silent ?? !debugLogs);
    final isValid = rules.validate();
    return isValid;
  }
}
