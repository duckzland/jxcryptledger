import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../app/exceptions.dart';
import '../../core/abstracts/controller.dart';
import '../../core/math.dart';
import '../../core/mixins/controllers/exportable.dart';
import '../../core/mixins/controllers/id_generator.dart';
import '../../core/mixins/controllers/rateable.dart';
import 'model.dart';
import 'repository.dart';

class TransactionsController extends CoreBaseController<TransactionsModel, TransactionsRepository>
    with
        CoreMixinsControllersIdGenerator<TransactionsModel, TransactionsRepository>,
        CoreMixinsControllersExportable<TransactionsModel, TransactionsRepository>,
        CoreMixinsControllersRateable<TransactionsModel, TransactionsRepository> {
  TransactionsController(super.repo);

  @override
  Future<void> init() async {
    await super.init();
    scheduleRates();
  }

  Future<void> close(TransactionsModel tx) async {
    await repo.close(tx);
    load();
  }

  Future<void> finalize(TransactionsModel tx) async {
    await repo.finalize(tx);
    load();
  }

  Future<void> refund(TransactionsModel tx) async {
    await repo.refund(tx);
    load();
  }

  Future<List<String>> addAll(List<TransactionsModel> txs) async {
    final result = await repo.addAll(txs);
    load();
    return result;
  }

  Future<List<String>> updateAll(List<TransactionsModel> txs) async {
    final result = await repo.updateAll(txs);
    load();
    return result;
  }

  Future<List<String>> closeAll(List<TransactionsModel> txs) async {
    final result = await repo.closeAll(txs);
    load();
    return result;
  }

  Future<List<String>> finalizeAll(List<TransactionsModel> txs) async {
    final result = await repo.finalizeAll(txs);
    load();
    return result;
  }

  Future<List<String>> refundAll(List<TransactionsModel> txs) async {
    final result = await repo.refundAll(txs);
    load();
    return result;
  }

  Future<List<String>> removeAll(List<TransactionsModel> txs) async {
    final result = await repo.removeAll(txs);
    load();
    return result;
  }

  TransactionsModel? getParent(TransactionsModel tx) {
    return repo.getIndexedMap()[tx.pid];
  }

  TransactionsModel? getRoot(TransactionsModel tx) {
    return repo.getIndexedMap()[tx.isRoot ? tx.tid : tx.rid];
  }

  Map<String, TransactionsModel> getIndexedMap() {
    return repo.getIndexedMap();
  }

  Map<String, List<TransactionsModel>> getIndexedParentMap() {
    return repo.getIndexedParentMap();
  }

  Map<String, Map<String, TransactionsModel>> getIndexedRootMap() {
    return repo.getIndexedRootMap();
  }

  bool hasLeaf(TransactionsModel tx) {
    final leaf = repo.getLeaf(tx);
    return leaf.isNotEmpty;
  }

  bool hasTradeableLeaf(TransactionsModel tx) {
    final leaves = repo.collectAllLeaves(tx);

    if (leaves.isEmpty) {
      return false;
    }

    for (final ttx in leaves) {
      if (ttx.isActive || ttx.isPartial) {
        return true;
      }
    }

    return false;
  }

  bool hasClosableLeaf() {
    final leaves = repo.collectAllTerminalLeaves();

    if (leaves.isEmpty) {
      return false;
    }

    for (final tx in leaves) {
      try {
        repo.canClose(tx, silent: true);
        return true;
      } catch (_) {
        // Ignore failures and continue
      }
    }

    return false;
  }

  bool hasFinalizable() {
    final txs = repo.extract();

    if (txs.isEmpty) {
      return false;
    }

    for (final tx in txs) {
      try {
        repo.canFinalize(tx, silent: true);
        return true;
      } catch (_) {
        // Ignore failures and continue
      }
    }

    return false;
  }

  bool hasDeletableRoot() {
    final roots = repo.collectAllRoots();

    if (roots.isEmpty) {
      return false;
    }

    for (final tx in roots) {
      try {
        repo.canDelete(tx, silent: true);
        return true;
      } catch (_) {
        // Ignore failures and continue
      }
    }
    return false;
  }

  bool isAddable(TransactionsModel tx) {
    try {
      repo.canAdd(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isClosable(TransactionsModel tx) {
    try {
      repo.canClose(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isDeletable(TransactionsModel tx) {
    try {
      repo.canDelete(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isUpdatable(TransactionsModel tx) {
    try {
      repo.canUpdate(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isTradable(TransactionsModel tx) {
    try {
      repo.canTrade(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isRefundable(TransactionsModel tx) {
    try {
      repo.canRefund(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isFinalizable(TransactionsModel tx) {
    try {
      repo.canFinalize(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isClosedTerminals(TransactionsModel tx) {
    final leaves = repo.collectTerminalLeaves(tx);

    for (final ltx in leaves) {
      if (!ltx.isClosed) {
        return false;
      }
    }

    return true;
  }

  Decimal getCapitalBalance(TransactionsModel tx) {
    final children = repo.getLeaf(tx);
    final Decimal spent = children.fold<Decimal>(Decimal.zero, (sum, leaf) => Math.add(sum, leaf.srAmount));
    final Decimal balance = Math.subtract(tx.rrAmount, spent);

    return balance;
  }

  List<TransactionsModel> collectAllRoots() {
    return repo.collectAllRoots();
  }

  Decimal collectAllTerminalResultAmount(TransactionsModel tx) {
    Decimal balance = Decimal.zero;
    final leaves = repo.collectAllTerminalLeaves();

    for (final ltx in leaves) {
      if (ltx.rrId == tx.rrId && ltx.isActive) {
        balance = Math.add(balance, ltx.balance);
      }
    }
    return balance;
  }

  Decimal collectBranchTotalResultAmount(TransactionsModel tx) {
    final txs = repo.collectAllLeaves(tx);
    Decimal balance = Decimal.zero;
    for (final rtx in txs) {
      if (rtx.rrId == tx.srId && (rtx.isActive || rtx.isPartial)) {
        balance = Math.add(balance, rtx.balance);
      }
    }

    return balance;
  }

  Map<int, Decimal> collectBranchActiveAmount(TransactionsModel tx) {
    final txs = repo.collectAllLeaves(tx);

    final Map<int, Decimal> branchAmounts = {};

    for (final rtx in txs) {
      if ((rtx.isActive || rtx.isPartial) && rtx.tid != tx.tid) {
        final key = rtx.rrId;
        branchAmounts[key] = Math.add(branchAmounts[key] ?? Decimal.zero, rtx.balance);
      }
    }

    return branchAmounts;
  }

  Map<int, Decimal> collectBranchFinalizedAmount(TransactionsModel tx) {
    final txs = repo.collectAllLeaves(tx);

    final Map<int, Decimal> branchAmounts = {};

    for (final rtx in txs) {
      if ((rtx.isFinalized) && rtx.tid != tx.tid) {
        final key = rtx.rrId;
        branchAmounts[key] = Math.add(branchAmounts[key] ?? Decimal.zero, rtx.balance);
      }
    }

    return branchAmounts;
  }

  List<TransactionsModel> collectTradableLeaves(TransactionsModel tx) {
    final leaves = repo.collectAllLeaves(tx);

    if (leaves.isEmpty) {
      return [];
    }

    final tradableLeaves = <TransactionsModel>[];
    for (final ttx in leaves) {
      if (ttx.isActive || ttx.isPartial) {
        tradableLeaves.add(ttx);
      }
    }

    return tradableLeaves;
  }

  List<TransactionsModel> collectBranchWithTarget(TransactionsModel target) {
    final lookup = repo.getIndexedMap();
    final children = repo.getIndexedParentMap();
    final List<TransactionsModel> branch = [];
    TransactionsModel? current = target;

    while (current != null) {
      branch.insert(0, current);
      if (current.isRoot) break;
      current = lookup[current.pid];
    }

    final List<TransactionsModel> descendants = [];
    void collectChildren(TransactionsModel node) {
      for (final tx in children[node.tid] ?? const <TransactionsModel>[]) {
        descendants.add(tx);
        collectChildren(tx);
      }
    }

    collectChildren(target);

    return [...branch, ...descendants];
  }

  bool isBothEqual(TransactionsModel txA, TransactionsModel txB) {
    if (txA.tid != txB.tid ||
        txA.rid != txB.rid ||
        txA.pid != txB.pid ||
        txA.srId != txB.srId ||
        txA.rrId != txB.rrId ||
        txA.srAmount != txB.srAmount ||
        txA.rrAmount != txB.rrAmount ||
        txA.balance != txB.balance ||
        txA.status != txB.status ||
        txA.closable != txB.closable ||
        txA.timestamp != txB.timestamp ||
        !mapEquals(txA.meta, txB.meta)) {
      return false;
    }

    return true;
  }

  bool isBothEqualGroup(List<TransactionsModel> a, List<TransactionsModel> b) {
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      final txA = a[i];
      final txB = b[i];

      if (!isBothEqual(txA, txB)) {
        return false;
      }
    }

    return true;
  }

  bool isEqualToItems(List<TransactionsModel> a) {
    return isBothEqualGroup(a, items);
  }
}
