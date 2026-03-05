import 'package:flutter/foundation.dart';

import '../../app/exceptions.dart';
import '../../core/log.dart';
import 'model.dart';
import 'repository.dart';

class TransactionsController extends ChangeNotifier {
  final TransactionsRepository repo;

  List<TransactionsModel> _items = [];
  List<TransactionsModel> get items => _items;

  TransactionsController(this.repo);

  String generateTid() {
    return repo.generateTid();
  }

  Future<void> load() async {
    _items = await repo.getAll();
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      await load();
      return;
    }

    _items = await repo.filter(query);
    notifyListeners();
  }

  Future<TransactionsModel?> get(String tid) async {
    final tx = await repo.get(tid);
    await load();
    return tx;
  }

  Future<void> add(TransactionsModel tx) async {
    try {
      await repo.add(tx);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> update(TransactionsModel tx) async {
    try {
      await repo.update(tx);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> delete(TransactionsModel tx) async {
    try {
      await repo.delete(tx);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> closeLeaf(TransactionsModel tx) async {
    try {
      await repo.close(tx);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  Future<TransactionsModel?> getParent(TransactionsModel tx) async {
    try {
      TransactionsModel? ptx = await repo.get(tx.pid);
      return ptx;
    } catch (e) {
      return null;
    }
  }

  Future<void> removeRoot(TransactionsModel tx) async {
    try {
      await repo.delete(tx);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeLeaf(TransactionsModel tx) async {
    try {
      await repo.refund(tx);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAll() async {
    final roots = await repo.collectAllRoots();

    for (final tx in roots) {
      final bool deletable;
      try {
        deletable = await isDeletable(tx);
      } catch (_) {
        continue;
      }

      if (!deletable) continue;

      await repo.delete(tx);
    }

    await load();
  }

  Future<void> closeAll() async {
    final leaves = await repo.collectAllTerminalLeaves();

    for (final tx in leaves) {
      final bool closable;
      try {
        closable = await isClosable(tx);
      } catch (_) {
        continue;
      }

      if (!closable) continue;

      await repo.close(tx);
    }

    await load();
  }

  Future<bool> wipeAll() async {
    try {
      final removed = await repo.clear();
      await load();
      return removed != 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasLeaf(TransactionsModel tx) async {
    try {
      final leaf = await repo.getLeaf(tx);
      return leaf.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasClosableLeaf() async {
    try {
      final leaves = await repo.collectAllTerminalLeaves();

      for (final tx in leaves) {
        try {
          await repo.canClose(tx, silent: true);
          return true;
        } catch (_) {
          // Ignore failures and continue
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasDeletableRoot() async {
    try {
      final roots = await repo.collectAllRoots();
      for (final tx in roots) {
        try {
          await repo.canDelete(tx, silent: true);
          return true;
        } catch (_) {
          // Ignore failures and continue
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isAddable(TransactionsModel tx) async {
    try {
      await repo.canAdd(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isClosable(TransactionsModel tx) async {
    try {
      await repo.canClose(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isDeletable(TransactionsModel tx) async {
    try {
      await repo.canDelete(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isUpdatable(TransactionsModel tx) async {
    try {
      await repo.canUpdate(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isTradable(TransactionsModel tx) async {
    try {
      await repo.canTrade(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isRefundable(TransactionsModel tx) async {
    try {
      await repo.canRefund(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isEmpty() {
    return repo.isEmpty();
  }

  Future<double> getCapitalBalance(TransactionsModel tx) async {
    final children = await repo.getLeaf(tx);
    final double spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final double balance = tx.rrAmount - spent;

    return balance;
  }

  Future<List<TransactionsModel>> collectAllRoots() async {
    return await repo.collectAllRoots();
  }

  Future<double> collectAllTerminalResultAmount(TransactionsModel tx) async {
    double balance = 0;
    final leaves = await repo.collectAllTerminalLeaves();

    for (final ltx in leaves) {
      if (ltx.rrId == tx.rrId && ltx.isActive) {
        balance += ltx.balance;
      }
    }
    return balance;
  }

  Future<double> collectBranchTotalResultAmount(TransactionsModel tx) async {
    final txs = await repo.collectDescendantLeaves(tx);
    double balance = 0;
    for (final rtx in txs) {
      if (rtx.rrId == tx.srId && (rtx.isActive || rtx.isPartial)) {
        balance += rtx.balance;
      }
    }

    return balance;
  }

  Future<Map<int, double>> collectBranchActiveAmount(TransactionsModel tx) async {
    final txs = await repo.collectDescendantLeaves(tx);

    final Map<int, double> branchAmounts = {};

    for (final rtx in txs) {
      if (rtx.isActive || rtx.isPartial) {
        final key = rtx.rrId;
        branchAmounts[key] = (branchAmounts[key] ?? 0) + rtx.balance;
      }
    }

    return branchAmounts;
  }

  Future<String> exportDatabase() async {
    try {
      return await repo.export();
    } catch (e) {
      return '';
    }
  }

  Future<void> importDatabase(String rawJson) async {
    try {
      await repo.import(rawJson);
      await load();
    } catch (e) {
      rethrow;
    }
  }
}
