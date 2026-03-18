import 'package:flutter/foundation.dart';

import '../../app/exceptions.dart';
import '../rates/service.dart';
import 'model.dart';
import 'repository.dart';

class TransactionsController extends ChangeNotifier {
  final TransactionsRepository _repo;
  final RatesService _ratesService;

  List<TransactionsModel> _items = [];
  List<TransactionsModel> get items => _items;

  TransactionsController(this._repo, this._ratesService);

  String generateTid() {
    return _repo.generateId();
  }

  Future<void> load() async {
    _items = await _repo.getAll();
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      await load();
      return;
    }

    _items = await _repo.filter(query);
    notifyListeners();
  }

  Future<TransactionsModel?> get(String tid) async {
    final tx = await _repo.get(tid);
    await load();
    return tx;
  }

  Future<void> add(TransactionsModel tx) async {
    await _repo.add(tx);
    await load();
  }

  Future<void> update(TransactionsModel tx) async {
    await _repo.update(tx);
    await load();
  }

  Future<void> delete(TransactionsModel tx) async {
    await _ratesService.delete(tx.srId, tx.rrId);
    await _ratesService.delete(tx.rrId, tx.srId);
    await _repo.delete(tx);
    await load();
  }

  Future<void> closeLeaf(TransactionsModel tx) async {
    await _repo.close(tx);
    await load();
  }

  Future<TransactionsModel?> getParent(TransactionsModel tx) async {
    return await _repo.get(tx.pid);
  }

  Future<void> removeRoot(TransactionsModel tx) async {
    await _repo.delete(tx);
    await load();
  }

  Future<void> removeLeaf(TransactionsModel tx) async {
    await _repo.refund(tx);
    await load();
  }

  Future<void> deleteAll() async {
    final roots = await _repo.collectAllRoots();

    for (final tx in roots) {
      final bool deletable;
      try {
        deletable = await isDeletable(tx);
      } catch (_) {
        continue;
      }

      if (!deletable) continue;

      await _repo.delete(tx);
    }

    await load();
  }

  Future<void> closeAll() async {
    final leaves = await _repo.collectAllTerminalLeaves();

    for (final tx in leaves) {
      final bool closable;
      try {
        closable = await isClosable(tx);
      } catch (_) {
        continue;
      }

      if (!closable) continue;

      await _repo.close(tx);
    }

    await load();
  }

  Future<bool> wipeAll() async {
    try {
      final removed = await _repo.clear();
      await load();
      return removed != 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasLeaf(TransactionsModel tx) async {
    try {
      final leaf = await _repo.getLeaf(tx);
      return leaf.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasClosableLeaf() async {
    try {
      final leaves = await _repo.collectAllTerminalLeaves();

      for (final tx in leaves) {
        try {
          await _repo.canClose(tx, silent: true);
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
      final roots = await _repo.collectAllRoots();
      for (final tx in roots) {
        try {
          await _repo.canDelete(tx, silent: true);
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
      await _repo.canAdd(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isClosable(TransactionsModel tx) async {
    try {
      await _repo.canClose(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isDeletable(TransactionsModel tx) async {
    try {
      await _repo.canDelete(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isUpdatable(TransactionsModel tx) async {
    try {
      await _repo.canUpdate(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isTradable(TransactionsModel tx) async {
    try {
      await _repo.canTrade(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isRefundable(TransactionsModel tx) async {
    try {
      await _repo.canRefund(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isEmpty() {
    return _repo.isEmpty();
  }

  Future<double> getCapitalBalance(TransactionsModel tx) async {
    final children = await _repo.getLeaf(tx);
    final double spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final double balance = tx.rrAmount - spent;

    return balance;
  }

  Future<List<TransactionsModel>> collectAllRoots() async {
    return await _repo.collectAllRoots();
  }

  Future<double> collectAllTerminalResultAmount(TransactionsModel tx) async {
    double balance = 0;
    final leaves = await _repo.collectAllTerminalLeaves();

    for (final ltx in leaves) {
      if (ltx.rrId == tx.rrId && ltx.isActive) {
        balance += ltx.balance;
      }
    }
    return balance;
  }

  Future<double> collectBranchTotalResultAmount(TransactionsModel tx) async {
    final txs = await _repo.collectDescendantLeaves(tx);
    double balance = 0;
    for (final rtx in txs) {
      if (rtx.rrId == tx.srId && (rtx.isActive || rtx.isPartial)) {
        balance += rtx.balance;
      }
    }

    return balance;
  }

  Future<Map<int, double>> collectBranchActiveAmount(TransactionsModel tx) async {
    final txs = await _repo.collectDescendantLeaves(tx);

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
      return await _repo.export();
    } catch (e) {
      return '';
    }
  }

  Future<void> importDatabase(String rawJson) async {
    try {
      await _repo.import(rawJson);
      await load();
    } catch (e) {
      rethrow;
    }
  }
}
