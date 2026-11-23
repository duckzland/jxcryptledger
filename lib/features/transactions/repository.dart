import 'package:decimal/decimal.dart' show Decimal;

import '../../core/mixins/repositories/exportable.dart';
import '../../core/mixins/repositories/id_generator.dart';
import '../../core/abstracts/repository.dart';
import '../../core/log.dart';
import '../../core/math.dart';
import '../../ipc/status/op.dart';
import 'index.dart';
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

  late final _cache = TransactionsIndex(() => extract());

  void resetIndexes() => _cache.invalidate();

  Map<String, TransactionsModel> getIndexedMap() => _cache.byTid;
  Map<String, List<TransactionsModel>> getIndexedParentMap() => _cache.byPid;
  Map<String, Map<String, TransactionsModel>> getIndexedRootMap() => _cache.byRid;

  @override
  void receive(event) {
    super.receive(event);

    if (event.action != boxName) {
      return;
    }

    final opName = IpcStatusOp.getName(event.actionCode);

    switch (opName) {
      case "put":
        final data = event.payload as TransactionsModel;
        _cache.update(data);
        break;

      case "delete":
        _cache.removeByTid(event.key);
        break;

      case "clear":
        _cache.invalidate();
        break;

      case "multiPut":
      case "replace":
        _cache.invalidate();
        _cache.generate();
        break;

      default:
        break;
    }
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
      _cache.update(ntx);
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
      _cache.update(ntx);

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
      _cache.update(ntx);
      return;
    }

    // Update the parent balance and status
    // This is important to preserve valid tree structure!
    if (tx.isLeaf) {
      TransactionsModel? ptx = box.get(ntx.pid)!;
      TransactionsModel? otx = box.get(ntx.tid)!;

      await box.put(ntx.tid, ntx);
      _cache.update(ntx);

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

    // Collect only descendants of tx via the indexed tree (instead of scanning the whole box)
    final descendants = collectAllLeaves(tx);
    for (final ttx in descendants) {
      if (debugLogs) {
        logln(
          "${ttx.tid}|${ttx.pid}|${ttx.rid}|${ttx.srId}|${ttx.srAmount}|${ttx.rrId}|${ttx.rrAmount}|${ttx.balance}|${ttx.status}|${ttx.closable}|${ttx.timestamp}",
          "DELETE",
        );
      }

      await box.delete(ttx.tid);
      _cache.removeByTid(ttx.tid);
    }

    await box.delete(tx.tid);
    _cache.removeByTid(tx.tid);
  }

  @override
  Future<void> delete(String id) async {
    await super.delete(id);
    _cache.removeByTid(id);
  }

  @override
  Future<int> clear() async {
    final count = await super.clear();
    _cache.invalidate();
    return count;
  }

  @override
  Future<void> addAll(List<TransactionsModel> values) async {
    await super.addAll(values);
    for (final tx in values) {
      _cache.update(tx);
    }
  }

  @override
  Future<void> replace(List<TransactionsModel> values) async {
    await super.replace(values);
    _cache.invalidate();
    _cache.generate();
  }

  @override
  Future<void> import(String rawJson) async {
    final rule = TransactionsRulesImport();
    final txs = rule.validateJson(rawJson);
    await box.replace(txs);
    _cache.invalidate();
    _cache.generate();
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
    _cache.update(closedTx);

    await box.put(updatedTarget.tid, updatedTarget);
    _cache.update(updatedTarget);
  }

  Future<List<String>> closeAll(List<TransactionsModel> txs) async {
    final Map<dynamic, TransactionsModel> pendingUpdates = {};
    List<TransactionsModel> closed = [];
    List<String> result = [];

    TransactionsModel? getLatest(dynamic tid) => pendingUpdates[tid] ?? box.get(tid);

    for (final tx in txs) {
      try {
        canClose(tx);

        TransactionsModel? otx = getLatest(tx.tid);
        if (otx == null) {
          continue;
        }

        TransactionsModel? rawTarget = getCloseTargetParent(otx);
        if (rawTarget == null) {
          continue;
        }

        TransactionsModel target = getLatest(rawTarget.tid) ?? rawTarget;

        bool allClosed = false;
        List<TransactionsModel> leaves = [];

        leaves = collectTerminalLeaves(target).map((leaf) => getLatest(leaf.tid) ?? leaf).toList();

        allClosed =
            leaves.isNotEmpty &&
            leaves
                // Current tx hasn't mutated status yet thus ignore it!
                .where((leaf) => leaf.tid != otx.tid)
                .every((leaf) => leaf.statusEnum == TransactionStatus.closed);

        if (allClosed) {
          leaves = collectInBetweenLeaves(otx, target).map((leaf) => getLatest(leaf.tid) ?? leaf).toList();

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
            "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
            "CLOSING",
          );
        }

        pendingUpdates[closedTx.tid] = closedTx;
        pendingUpdates[updatedTarget.tid] = updatedTarget;
        closed.add(closedTx);
      } catch (_) {
        continue;
      }
    }

    if (closed.isNotEmpty) {
      final allToSave = pendingUpdates.values.toList();
      await box.addAll(allToSave);

      for (final tx in allToSave) {
        _cache.update(tx);
      }

      for (final tx in closed) {
        result.add(tx.uuid);
      }
    }

    return result;
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
    _cache.remove(tx);

    await box.put(utx.tid, utx);
    _cache.update(utx);
  }

  Future<List<String>> refundAll(List<TransactionsModel> txs) async {
    final Map<dynamic, TransactionsModel> pendingUpdates = {};
    final Set<dynamic> deletedTids = {};
    List<TransactionsModel> deletedTxs = [];
    List<String> deleted = [];

    TransactionsModel? getLatest(dynamic tid) {
      if (deletedTids.contains(tid)) return null;
      return pendingUpdates[tid] ?? box.get(tid);
    }

    for (final tx in txs) {
      try {
        canRefund(tx);

        TransactionsModel? otx = getLatest(tx.tid);
        TransactionsModel? ptx = getLatest(tx.pid);
        if (otx == null || ptx == null) {
          continue;
        }

        final leaves = collectTerminalLeaves(
          ptx,
        ).where((leaf) => !deletedTids.contains(leaf.tid)).map((leaf) => getLatest(leaf.tid) ?? leaf).toList();

        final allClosed =
            leaves.isNotEmpty &&
            leaves
                // Current tx hasn't been removed yet thus ignore it!
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

        deletedTids.add(tx.tid);
        pendingUpdates.remove(tx.tid);
        pendingUpdates[utx.tid] = utx;
        deletedTxs.add(tx);
      } catch (_) {
        continue;
      }
    }

    if (deletedTxs.isNotEmpty) {
      for (final tx in deletedTxs) {
        await box.delete(tx.tid);
        _cache.remove(tx);
        deleted.add(tx.uuid);
      }
    }

    if (pendingUpdates.isNotEmpty) {
      final allToSave = pendingUpdates.values.toList();
      await box.addAll(allToSave);
      for (final tx in allToSave) {
        _cache.update(tx);
      }
    }

    return deleted;
  }

  Future<void> finalize(TransactionsModel tx) async {
    if (tx.statusEnum == TransactionStatus.finalized) {
      return;
    }

    canFinalize(tx);

    final ntx = tx.copyWith(status: TransactionStatus.finalized.index);

    if (debugLogs) {
      logln(
        "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
        "FINALIZING",
      );
    }

    await box.put(ntx.tid, tx);
    _cache.update(ntx);
  }

  Future<List<String>> finalizeAll(List<TransactionsModel> txs) async {
    List<TransactionsModel> success = [];
    List<String> result = [];

    for (final tx in txs) {
      try {
        if (tx.statusEnum == TransactionStatus.finalized) {
          continue;
        }

        canFinalize(tx);

        final ntx = tx.copyWith(status: TransactionStatus.finalized.index);

        if (debugLogs) {
          logln(
            "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
            "FINALIZING",
          );
        }

        success.add(ntx);
      } catch (_) {
        continue;
      }
    }

    if (success.isNotEmpty) {
      await box.addAll(success);

      for (final tx in success) {
        _cache.update(tx);
        result.add(tx.uuid);
      }
    }

    return result;
  }

  Future<List<String>> removeAll(List<TransactionsModel> txs) async {
    List<String> deleted = [];
    final Set<dynamic> deletedTids = {};

    for (final tx in txs) {
      if (deletedTids.contains(tx.tid)) {
        deleted.add(tx.uuid);
        continue;
      }

      try {
        canDelete(tx);

        if (debugLogs) {
          logln(
            "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
            "DELETE",
          );
        }

        final descendants = collectAllLeaves(tx);
        for (final ttx in descendants) {
          if (deletedTids.contains(ttx.tid)) continue;

          if (debugLogs) {
            logln(
              "${ttx.tid}|${ttx.pid}|${ttx.rid}|${ttx.srId}|${ttx.srAmount}|${ttx.rrId}|${ttx.rrAmount}|${ttx.balance}|${ttx.status}|${ttx.closable}|${ttx.timestamp}",
              "DELETE",
            );
          }

          await box.delete(ttx.tid);
          _cache.removeByTid(ttx.tid);
          deletedTids.add(ttx.tid);
        }

        await box.delete(tx.tid);
        _cache.removeByTid(tx.tid);
        deletedTids.add(tx.tid);

        deleted.add(tx.uuid);
      } catch (_) {
        continue;
      }
    }

    return deleted;
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
    final leaves = <TransactionsModel>[];

    void dfs(TransactionsModel node) {
      final children = childrenMap[node.tid];
      if (children == null || children.isEmpty) {
        if (node.tid != parent.tid) {
          leaves.add(node);
        }
        return;
      }

      for (final child in children) {
        dfs(child);
      }
    }

    dfs(parent);
    return leaves;
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
    final lookup = getIndexedMap();

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
