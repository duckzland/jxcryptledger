import 'package:decimal/decimal.dart' show Decimal;

import '../../core/mixins/repositories/exportable.dart';
import '../../core/mixins/repositories/id_generator.dart';
import '../../core/abstracts/repository.dart';
import '../../core/log.dart';
import '../../core/math.dart';
import '../../ipc/status/op.dart';
import 'helper.dart';
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

      case "multiDelete":
        final keys = event.payload;
        if (keys is List) {
          for (final key in keys) {
            _cache.removeByTid(key);
          }
        }
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
    final descendants = TransactionsHelper.collectAllLeaves(tx, childrenMap: getIndexedParentMap());
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
  Future<void> replace(List<TransactionsModel> txs) async {
    await super.replace(txs);
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

    TransactionsModel? otx = box.get(tx.tid);
    if (otx == null) {
      return;
    }
    TransactionsModel? target = TransactionsHelper.getCloseTargetParent(otx, txsMap: getIndexedRootMap()[otx.rid] ?? getIndexedMap());
    bool allClosed = false;
    List<TransactionsModel> leaves = [];

    if (target == null) {
      return;
    }

    leaves = TransactionsHelper.collectTerminalLeaves(target, childrenMap: getIndexedParentMap());

    allClosed =
        leaves.isNotEmpty &&
        leaves
            // Current tx hasn't mutate status yet thus ignore it!
            .where((leaf) => leaf.tid != otx.tid)
            .every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    if (allClosed) {
      leaves = TransactionsHelper.collectInBetweenLeaves(otx, target, txsMap: getIndexedRootMap()[otx.rid] ?? getIndexedMap());
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

  Future<void> refund(TransactionsModel tx) async {
    canRefund(tx);

    TransactionsModel? otx = box.get(tx.tid);
    TransactionsModel? ptx = box.get(tx.pid);
    if (otx == null || ptx == null) {
      return;
    }

    final leaves = TransactionsHelper.collectTerminalLeaves(ptx, childrenMap: getIndexedParentMap());
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

    await box.put(ntx.tid, ntx);
    _cache.update(ntx);
  }

  @override
  Future<List<String>> addAll(List<TransactionsModel> txs) async {
    if (txs.isEmpty) {
      return [];
    }

    final hasDuplicates = txs.map((tx) => tx.tid).toSet().length != txs.length;
    if (hasDuplicates) {
      if (debugLogs) {
        logln("Duplicate transaction found, refusing to proceed.", "ADD");
      }
      return [];
    }

    final Map<dynamic, TransactionsModel> pendingUpdates = {};
    final List<String> result = [];

    for (final tx in txs) {
      final Map<dynamic, TransactionsModel?> stepPendingBackup = {};

      void stageStep(TransactionsModel model) {
        stepPendingBackup.putIfAbsent(model.tid, () => pendingUpdates[model.tid]);
        pendingUpdates[model.tid] = model;
      }

      try {
        if (debugLogs) {
          logln(
            "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
            "ADD",
          );
        }

        TransactionsModel ntx = tx;

        bool isClosable;
        try {
          isClosable = canClose(ntx, overlay: pendingUpdates);
        } catch (_) {
          isClosable = false;
        }

        if (tx.isClosable != isClosable) {
          ntx = ntx.copyWith(closable: isClosable);
        }

        canAdd(ntx, overlay: pendingUpdates);

        if (ntx.isRoot) {
          stageStep(ntx);
          result.add(ntx.tid);
          continue;
        }

        if (ntx.isLeaf) {
          final ptx = pendingUpdates[ntx.pid] ?? box.get(ntx.pid);
          if (ptx == null) {
            continue;
          }

          canTrade(ptx, overlay: pendingUpdates);
          canUpdate(ptx, overlay: pendingUpdates);

          final balance = Math.subtract(ptx.balance, ntx.srAmount);
          final status = balance <= Decimal.zero ? TransactionStatus.inactive.index : TransactionStatus.partial.index;

          var nptx = ptx.copyWith(balance: balance, status: status);

          logln("Rebalancing amount $balance|${ptx.balance}|${ntx.srAmount}|${ptx.rrId}|${ntx.srId}", "ADD");

          stageStep(ntx);

          if (debugLogs) {
            logln(
              "${nptx.tid}|${nptx.pid}|${nptx.rid}|${nptx.srId}|${nptx.srAmount}|${nptx.rrId}|${nptx.rrAmount}|${nptx.balance}|${nptx.status}|${nptx.closable}|${nptx.timestamp}",
              "UPDATE",
            );
          }

          bool parentClosable;
          try {
            parentClosable = canClose(nptx, overlay: pendingUpdates);
          } catch (_) {
            parentClosable = false;
          }

          if (nptx.isClosable != parentClosable) {
            nptx = nptx.copyWith(closable: parentClosable);
          }

          canUpdate(nptx, overlay: pendingUpdates);

          stageStep(nptx);
          result.add(ntx.tid);
        }
      } catch (_) {
        stepPendingBackup.forEach((tid, prev) {
          if (prev == null) {
            pendingUpdates.remove(tid);
          } else {
            pendingUpdates[tid] = prev;
          }
        });
        continue;
      }
    }

    if (pendingUpdates.isNotEmpty) {
      final allToSave = pendingUpdates.values.toList();
      await box.addAll(allToSave);

      for (final tx in allToSave) {
        _cache.update(tx);
      }
    }

    return result;
  }

  @override
  Future<void> deleteAll(List<TransactionsModel> txs) async {
    await super.deleteAll(txs);
    for (final tx in txs) {
      _cache.remove(tx);
    }
  }

  Future<List<String>> updateAll(List<TransactionsModel> txs) async {
    if (txs.isEmpty) {
      return [];
    }

    final hasDuplicates = txs.map((tx) => tx.tid).toSet().length != txs.length;
    if (hasDuplicates) {
      if (debugLogs) {
        logln("Duplicate transaction found, refusing to proceed.", "UPDATE");
      }
      return [];
    }

    final Map<dynamic, TransactionsModel> pendingUpdates = {};
    final List<String> result = [];

    for (final tx in txs) {
      final Map<dynamic, TransactionsModel?> stepPendingBackup = {};

      void stageStep(TransactionsModel model) {
        stepPendingBackup.putIfAbsent(model.tid, () => pendingUpdates[model.tid]);
        pendingUpdates[model.tid] = model;
      }

      try {
        if (debugLogs) {
          logln(
            "${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}",
            "UPDATE",
          );
        }

        TransactionsModel ntx = tx;
        bool isClosable;
        try {
          isClosable = canClose(ntx, overlay: pendingUpdates);
        } catch (_) {
          isClosable = false;
        }

        if (tx.isClosable != isClosable) {
          ntx = ntx.copyWith(closable: isClosable);
        }

        canUpdate(ntx, overlay: pendingUpdates);

        if (ntx.isRoot) {
          stageStep(ntx);
          result.add(ntx.tid);
          continue;
        }

        if (ntx.isLeaf) {
          final otx = pendingUpdates[ntx.tid] ?? box.get(ntx.tid);
          final ptx = pendingUpdates[ntx.pid] ?? box.get(ntx.pid);
          if (otx == null || ptx == null) {
            continue;
          }

          stageStep(ntx);

          if (otx.srAmount != ntx.srAmount && ptx.rrId == otx.srId) {
            Decimal balance = ptx.balance;
            if (otx.srAmount > ntx.srAmount) {
              balance = Math.add(balance, Math.subtract(otx.srAmount, ntx.srAmount));
            } else {
              final spent = Math.subtract(ntx.srAmount, otx.srAmount);
              if (balance >= spent) {
                balance = Math.subtract(balance, spent);
              }
            }

            if (debugLogs) {
              logln(
                "Rebalancing amount ${otx.srAmount}|${ntx.srAmount}|${ptx.rrId}|${otx.srId}|${ntx.balance}|${otx.balance}|$balance",
                "UPDATE",
              );
            }

            var nptx = ptx.copyWith(
              balance: balance,
              status: balance > Decimal.zero ? TransactionStatus.partial.index : TransactionStatus.inactive.index,
            );

            bool parentClosable;
            try {
              parentClosable = canClose(nptx, overlay: pendingUpdates);
            } catch (_) {
              parentClosable = false;
            }

            if (nptx.isClosable != parentClosable) {
              nptx = nptx.copyWith(closable: parentClosable);
            }

            canUpdate(nptx, overlay: pendingUpdates);
            stageStep(nptx);
          }

          result.add(ntx.tid);
        }
      } catch (_) {
        stepPendingBackup.forEach((tid, prev) {
          if (prev == null) {
            pendingUpdates.remove(tid);
          } else {
            pendingUpdates[tid] = prev;
          }
        });
        continue;
      }
    }

    if (pendingUpdates.isNotEmpty) {
      final allToSave = pendingUpdates.values.toList();
      await box.addAll(allToSave);

      for (final tx in allToSave) {
        _cache.update(tx);
      }
    }

    return result;
  }

  Future<List<String>> closeAll(List<TransactionsModel> txs) async {
    if (txs.isEmpty) {
      return [];
    }

    final hasDuplicates = txs.map((tx) => tx.tid).toSet().length != txs.length;
    if (hasDuplicates) {
      if (debugLogs) {
        logln("Duplicate transaction found, refusing to proceed.", "CLOSING");
      }
      return [];
    }

    final Map<dynamic, TransactionsModel> pendingUpdates = {};
    final List<String> result = [];

    TransactionsModel? getLatest(dynamic tid) {
      if (pendingUpdates.containsKey(tid)) {
        return pendingUpdates[tid];
      }
      return box.get(tid);
    }

    for (final tx in txs) {
      try {
        final otx = getLatest(tx.tid);
        if (otx == null) {
          continue;
        }

        canClose(otx, overlay: pendingUpdates);

        final rawTarget = TransactionsHelper.getCloseTargetParent(otx, txsMap: getIndexedRootMap()[otx.rid] ?? getIndexedMap());
        if (rawTarget == null) {
          continue;
        }

        final target = getLatest(rawTarget.tid) ?? rawTarget;
        final terminalLeaves = TransactionsHelper.collectTerminalLeaves(target, childrenMap: getIndexedParentMap()).map((leaf) {
          return getLatest(leaf.tid) ?? leaf;
        }).toList();

        bool allClosed =
            terminalLeaves.isNotEmpty &&
            terminalLeaves.where((leaf) => leaf.tid != otx.tid).every((leaf) => leaf.statusEnum == TransactionStatus.closed);

        if (allClosed) {
          final inBetweenLeaves =
              TransactionsHelper.collectInBetweenLeaves(otx, target, txsMap: getIndexedRootMap()[otx.rid] ?? getIndexedMap()).map((leaf) {
                return getLatest(leaf.tid) ?? leaf;
              }).toList();

          allClosed =
              inBetweenLeaves.isNotEmpty &&
              inBetweenLeaves
                  .where((leaf) => leaf.tid != otx.tid)
                  .where((leaf) => leaf.tid != target.tid)
                  .every((leaf) => leaf.statusEnum == TransactionStatus.inactive);
        }

        final newStatus = allClosed ? TransactionStatus.active.index : TransactionStatus.partial.index;

        final updatedTarget = target.copyWith(balance: Math.add(target.balance, otx.balance), status: newStatus);

        final closedTx = otx.copyWith(balance: Decimal.zero, status: TransactionStatus.closed.index);

        if (debugLogs) {
          logln(
            "${otx.tid}|${otx.pid}|${otx.rid}|${otx.srId}|${otx.srAmount}|${otx.rrId}|${otx.rrAmount}|${otx.balance}|${otx.status}|${otx.closable}|${otx.timestamp}",
            "CLOSING",
          );
        }

        pendingUpdates[closedTx.tid] = closedTx;
        pendingUpdates[updatedTarget.tid] = updatedTarget;
        result.add(closedTx.tid);
      } catch (_) {
        continue;
      }
    }

    if (pendingUpdates.isNotEmpty) {
      final allToSave = pendingUpdates.values.toList();
      await box.addAll(allToSave);

      for (final tx in allToSave) {
        _cache.update(tx);
      }
    }

    return result;
  }

  Future<List<String>> refundAll(List<TransactionsModel> txs) async {
    if (txs.isEmpty) {
      return [];
    }

    final hasDuplicates = txs.map((tx) => tx.tid).toSet().length != txs.length;
    if (hasDuplicates) {
      if (debugLogs) {
        logln("Duplicate transaction found, refusing to proceed.", "REFUNDING");
      }
      return [];
    }

    final Map<dynamic, TransactionsModel> pendingUpdates = {};
    final Set<dynamic> deletedTids = {};
    final List<TransactionsModel> deletedTxs = [];
    final List<String> result = [];

    TransactionsModel? getLatest(dynamic tid) {
      if (deletedTids.contains(tid)) {
        return null;
      }
      if (pendingUpdates.containsKey(tid)) {
        return pendingUpdates[tid];
      }
      return box.get(tid);
    }

    for (final tx in txs) {
      try {
        final otx = getLatest(tx.tid);
        if (otx == null) {
          continue;
        }

        canRefund(otx, overlay: pendingUpdates);

        final ptx = getLatest(otx.pid);
        if (ptx == null) {
          continue;
        }

        final remainingLeaves = TransactionsHelper.collectTerminalLeaves(ptx, childrenMap: getIndexedParentMap())
            .where((leaf) => !deletedTids.contains(leaf.tid))
            .where((leaf) => leaf.tid != otx.tid)
            .map((leaf) => getLatest(leaf.tid) ?? leaf)
            .toList();

        final allClosed = remainingLeaves.isEmpty || remainingLeaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed);

        final newStatus = allClosed ? TransactionStatus.active.index : TransactionStatus.partial.index;

        final updatedParent = ptx.copyWith(balance: Math.add(ptx.balance, otx.srAmount), status: newStatus);

        if (debugLogs) {
          logln(
            "${otx.tid}|${otx.pid}|${otx.rid}|${otx.srId}|${otx.srAmount}|${otx.rrId}|${otx.rrAmount}|${otx.balance}|${otx.status}|${otx.closable}|${otx.timestamp}",
            "REFUNDING",
          );
          logln(
            "${updatedParent.tid}|${updatedParent.pid}|${updatedParent.rid}|${updatedParent.srId}|${updatedParent.srAmount}|${updatedParent.rrId}|${updatedParent.rrAmount}|${updatedParent.balance}|${updatedParent.status}|${updatedParent.closable}|${updatedParent.timestamp}",
            "REBALANCING",
          );
        }

        deletedTids.add(otx.tid);
        pendingUpdates.remove(otx.tid);
        pendingUpdates[updatedParent.tid] = updatedParent;
        deletedTxs.add(otx);
        result.add(otx.tid);
      } catch (_) {
        continue;
      }
    }

    if (deletedTxs.isNotEmpty) {
      for (final tx in deletedTxs) {
        await box.delete(tx.tid);
        _cache.remove(tx);
      }
    }

    if (pendingUpdates.isNotEmpty) {
      final allToSave = pendingUpdates.values.toList();
      await box.addAll(allToSave);

      for (final tx in allToSave) {
        _cache.update(tx);
      }
    }

    return result;
  }

  Future<List<String>> finalizeAll(List<TransactionsModel> txs) async {
    if (txs.isEmpty) {
      return [];
    }

    final hasDuplicates = txs.map((tx) => tx.tid).toSet().length != txs.length;
    if (hasDuplicates) {
      if (debugLogs) {
        logln("Duplicate transaction found, refusing to proceed.", "FINALIZING");
      }
      return [];
    }

    final Map<dynamic, TransactionsModel> pendingUpdates = {};
    final List<String> result = [];

    for (final tx in txs) {
      try {
        final otx = pendingUpdates[tx.tid] ?? box.get(tx.tid);
        if (otx == null) {
          continue;
        }

        if (otx.statusEnum == TransactionStatus.finalized) {
          continue;
        }

        canFinalize(otx, overlay: pendingUpdates);

        final ntx = otx.copyWith(status: TransactionStatus.finalized.index);

        if (debugLogs) {
          logln(
            "${otx.tid}|${otx.pid}|${otx.rid}|${otx.srId}|${otx.srAmount}|${otx.rrId}|${otx.rrAmount}|${otx.balance}|${otx.status}|${otx.closable}|${otx.timestamp}",
            "FINALIZING",
          );
        }

        pendingUpdates[ntx.tid] = ntx;
        result.add(ntx.tid);
      } catch (_) {
        continue;
      }
    }

    if (pendingUpdates.isNotEmpty) {
      final allToSave = pendingUpdates.values.toList();
      await box.addAll(allToSave);

      for (final tx in allToSave) {
        _cache.update(tx);
      }
    }

    return result;
  }

  Future<List<String>> removeAll(List<TransactionsModel> txs) async {
    if (txs.isEmpty) {
      return [];
    }

    final hasDuplicates = txs.map((tx) => tx.tid).toSet().length != txs.length;
    if (hasDuplicates) {
      if (debugLogs) {
        logln("Duplicate transaction found, refusing to proceed.", "DELETE");
      }
      return [];
    }

    final List<String> result = [];
    final Set<dynamic> deletedTids = {};
    final List<TransactionsModel> toDelete = [];

    for (final tx in txs) {
      final otx = box.get(tx.tid);
      if (otx == null) {
        continue;
      }

      if (deletedTids.contains(otx.tid)) {
        result.add(otx.tid);
        continue;
      }

      try {
        canDelete(otx);

        if (debugLogs) {
          logln(
            "${otx.tid}|${otx.pid}|${otx.rid}|${otx.srId}|${otx.srAmount}|${otx.rrId}|${otx.rrAmount}|${otx.balance}|${otx.status}|${otx.closable}|${otx.timestamp}",
            "DELETE",
          );
        }

        final descendants = TransactionsHelper.collectAllLeaves(otx, childrenMap: getIndexedParentMap());
        for (final descendant in descendants) {
          if (deletedTids.contains(descendant.tid)) {
            continue;
          }

          if (debugLogs) {
            logln(
              "${descendant.tid}|${descendant.pid}|${descendant.rid}|${descendant.srId}|${descendant.srAmount}|${descendant.rrId}|${descendant.rrAmount}|${descendant.balance}|${descendant.status}|${descendant.closable}|${descendant.timestamp}",
              "DELETE",
            );
          }

          toDelete.add(descendant);
          deletedTids.add(descendant.tid);
        }

        toDelete.add(otx);
        deletedTids.add(otx.tid);
        result.add(otx.tid);
      } catch (_) {
        continue;
      }
    }

    if (toDelete.isNotEmpty) {
      await box.deleteAll(toDelete);

      for (final tx in toDelete) {
        _cache.removeByTid(tx.tid);
      }
    }

    return result;
  }

  bool canAdd(TransactionsModel tx, {bool? silent, Map<dynamic, TransactionsModel>? overlay}) {
    final hasOverlay = overlay != null && overlay.isNotEmpty;
    final rules = TransactionsRulesCreate(
      tx,
      hasOverlay ? {...getIndexedMap(), ...overlay.cast<String, TransactionsModel>()} : getIndexedMap(),
      hasOverlay ? const {} : getIndexedParentMap(),
      hasOverlay ? const {} : getIndexedRootMap(),
      silent ?? !debugLogs,
    );
    final isValid = rules.validate();
    return isValid;
  }

  bool canDelete(TransactionsModel tx, {bool? silent, Map<dynamic, TransactionsModel>? overlay}) {
    final hasOverlay = overlay != null && overlay.isNotEmpty;
    final rules = TransactionsRulesDelete(
      tx,
      hasOverlay ? {...getIndexedMap(), ...overlay.cast<String, TransactionsModel>()} : getIndexedMap(),
      hasOverlay ? const {} : getIndexedParentMap(),
      hasOverlay ? const {} : getIndexedRootMap(),
      silent ?? !debugLogs,
    );
    final isValid = rules.validate();
    return isValid;
  }

  bool canUpdate(TransactionsModel tx, {bool? silent = false, Map<dynamic, TransactionsModel>? overlay}) {
    final hasOverlay = overlay != null && overlay.isNotEmpty;
    final rules = TransactionsRulesUpdate(
      tx,
      hasOverlay ? {...getIndexedMap(), ...overlay.cast<String, TransactionsModel>()} : getIndexedMap(),
      hasOverlay ? const {} : getIndexedParentMap(),
      hasOverlay ? const {} : getIndexedRootMap(),
      silent ?? !debugLogs,
    );
    final isValid = rules.validate();
    return isValid;
  }

  bool canClose(TransactionsModel tx, {bool? silent = false, Map<dynamic, TransactionsModel>? overlay}) {
    final hasOverlay = overlay != null && overlay.isNotEmpty;
    final rules = TransactionsRulesClose(
      tx,
      hasOverlay ? {...getIndexedMap(), ...overlay.cast<String, TransactionsModel>()} : getIndexedMap(),
      hasOverlay ? const {} : getIndexedParentMap(),
      hasOverlay ? const {} : getIndexedRootMap(),
      silent ?? !debugLogs,
    );
    final isValid = rules.validate();
    return isValid;
  }

  bool canTrade(TransactionsModel tx, {bool? silent, Map<dynamic, TransactionsModel>? overlay}) {
    final hasOverlay = overlay != null && overlay.isNotEmpty;
    final rules = TransactionsRulesTrade(
      tx,
      hasOverlay ? {...getIndexedMap(), ...overlay.cast<String, TransactionsModel>()} : getIndexedMap(),
      hasOverlay ? const {} : getIndexedParentMap(),
      hasOverlay ? const {} : getIndexedRootMap(),
      silent ?? !debugLogs,
    );
    final isValid = rules.validate();
    return isValid;
  }

  bool canRefund(TransactionsModel tx, {bool? silent, Map<dynamic, TransactionsModel>? overlay}) {
    final hasOverlay = overlay != null && overlay.isNotEmpty;
    final rules = TransactionsRulesRefund(
      tx,
      hasOverlay ? {...getIndexedMap(), ...overlay.cast<String, TransactionsModel>()} : getIndexedMap(),
      hasOverlay ? const {} : getIndexedParentMap(),
      hasOverlay ? const {} : getIndexedRootMap(),
      silent ?? !debugLogs,
    );
    final isValid = rules.validate();
    return isValid;
  }

  bool canFinalize(TransactionsModel tx, {bool? silent, Map<dynamic, TransactionsModel>? overlay}) {
    final hasOverlay = overlay != null && overlay.isNotEmpty;
    final rules = TransactionsRulesFinalize(
      tx,
      hasOverlay ? {...getIndexedMap(), ...overlay.cast<String, TransactionsModel>()} : getIndexedMap(),
      hasOverlay ? const {} : getIndexedParentMap(),
      hasOverlay ? const {} : getIndexedRootMap(),
      silent ?? !debugLogs,
    );
    final isValid = rules.validate();
    return isValid;
  }
}
