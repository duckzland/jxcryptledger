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

  late final _cache = TransactionsIndex(() => box.items.cast<String, TransactionsModel>());

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

    final descendants = TransactionsHelper.collectAllLeaves(tx, childrenMap: getIndexedParentMap());
    final payload = [...descendants, tx];

    await box.deleteAll(payload);

    for (final ttx in payload) {
      if (debugLogs) {
        logln(
          "${ttx.tid}|${ttx.pid}|${ttx.rid}|${ttx.srId}|${ttx.srAmount}|${ttx.rrId}|${ttx.rrAmount}|${ttx.balance}|${ttx.status}|${ttx.closable}|${ttx.timestamp}",
          "DELETE",
        );
      }

      _cache.removeByTid(ttx.tid);
    }
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

    final List<String> result = [];

    for (final tx in txs) {
      try {
        await add(tx);
      } catch (_) {
        continue;
      }

      result.add(tx.tid);
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

  bool canAdd(TransactionsModel tx, {bool? silent}) {
    return TransactionsRulesCreate(tx, getIndexedMap(), getIndexedParentMap(), getIndexedRootMap(), silent ?? !debugLogs).validate();
  }

  bool canDelete(TransactionsModel tx, {bool? silent}) {
    return TransactionsRulesDelete(tx, getIndexedMap(), getIndexedParentMap(), getIndexedRootMap(), silent ?? !debugLogs).validate();
  }

  bool canUpdate(TransactionsModel tx, {bool? silent = false}) {
    return TransactionsRulesUpdate(tx, getIndexedMap(), getIndexedParentMap(), getIndexedRootMap(), silent ?? !debugLogs).validate();
  }

  bool canClose(TransactionsModel tx, {bool? silent = false}) {
    return TransactionsRulesClose(tx, getIndexedMap(), getIndexedParentMap(), getIndexedRootMap(), silent ?? !debugLogs).validate();
  }

  bool canTrade(TransactionsModel tx, {bool? silent}) {
    return TransactionsRulesTrade(tx, getIndexedMap(), getIndexedParentMap(), getIndexedRootMap(), silent ?? !debugLogs).validate();
  }

  bool canRefund(TransactionsModel tx, {bool? silent}) {
    return TransactionsRulesRefund(tx, getIndexedMap(), getIndexedParentMap(), getIndexedRootMap(), silent ?? !debugLogs).validate();
  }

  bool canFinalize(TransactionsModel tx, {bool? silent}) {
    return TransactionsRulesFinalize(tx, getIndexedMap(), getIndexedParentMap(), getIndexedRootMap(), silent ?? !debugLogs).validate();
  }
}
