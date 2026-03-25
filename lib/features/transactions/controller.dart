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

  void init() {
    load();
  }

  void start() {
    _items = _repo.getAll();
  }

  void load() {
    start();
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      load();
      return;
    }

    _items = await _repo.filter(query);
    notifyListeners();
  }

  TransactionsModel? get(String tid) {
    final tx = _repo.get(tid);
    load();
    return tx;
  }

  Future<void> add(TransactionsModel tx) async {
    await _repo.add(tx);
    load();
  }

  Future<void> update(TransactionsModel tx) async {
    await _repo.update(tx);
    load();
  }

  Future<void> delete(TransactionsModel tx) async {
    await _ratesService.delete(tx.srId, tx.rrId);
    await _ratesService.delete(tx.rrId, tx.srId);
    await _repo.delete(tx);
    load();
  }

  Future<void> closeLeaf(TransactionsModel tx) async {
    await _repo.close(tx);
    load();
  }

  TransactionsModel? getParent(TransactionsModel tx) {
    return _repo.get(tx.pid);
  }

  Future<void> removeRoot(TransactionsModel tx) async {
    await _repo.delete(tx);
    load();
  }

  Future<void> removeLeaf(TransactionsModel tx) async {
    await _repo.refund(tx);
    load();
  }

  Future<void> deleteAll() async {
    final roots = _repo.collectAllRoots();

    for (final tx in roots) {
      final bool deletable;
      try {
        deletable = isDeletable(tx);
      } catch (_) {
        continue;
      }

      if (!deletable) continue;

      await _repo.delete(tx);
    }

    load();
  }

  Future<void> closeAll() async {
    final leaves = _repo.collectAllTerminalLeaves();

    for (final tx in leaves) {
      final bool closable;
      try {
        closable = isClosable(tx);
      } catch (_) {
        continue;
      }

      if (!closable) continue;

      await _repo.close(tx);
    }

    load();
  }

  Future<bool> wipeAll() async {
    try {
      final removed = await _repo.clear();
      load();
      return removed != 0;
    } catch (e) {
      return false;
    }
  }

  bool hasLeaf(TransactionsModel tx) {
    try {
      final leaf = _repo.getLeaf(tx);
      return leaf.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  bool hasClosableLeaf() {
    try {
      final leaves = _repo.collectAllTerminalLeaves();

      for (final tx in leaves) {
        try {
          _repo.canClose(tx, silent: true);
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

  bool hasDeletableRoot() {
    try {
      final roots = _repo.collectAllRoots();
      for (final tx in roots) {
        try {
          _repo.canDelete(tx, silent: true);
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

  bool isAddable(TransactionsModel tx) {
    try {
      _repo.canAdd(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isClosable(TransactionsModel tx) {
    try {
      _repo.canClose(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isDeletable(TransactionsModel tx) {
    try {
      _repo.canDelete(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isUpdatable(TransactionsModel tx) {
    try {
      _repo.canUpdate(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isTradable(TransactionsModel tx) {
    try {
      _repo.canTrade(tx, silent: true);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  bool isRefundable(TransactionsModel tx) {
    try {
      _repo.canRefund(tx, silent: true);
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

  double getCapitalBalance(TransactionsModel tx) {
    final children = _repo.getLeaf(tx);
    final double spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final double balance = tx.rrAmount - spent;

    return balance;
  }

  List<TransactionsModel> collectAllRoots() {
    return _repo.collectAllRoots();
  }

  double collectAllTerminalResultAmount(TransactionsModel tx) {
    double balance = 0;
    final leaves = _repo.collectAllTerminalLeaves();

    for (final ltx in leaves) {
      if (ltx.rrId == tx.rrId && ltx.isActive) {
        balance += ltx.balance;
      }
    }
    return balance;
  }

  double collectBranchTotalResultAmount(TransactionsModel tx) {
    final txs = _repo.collectDescendantLeaves(tx);
    double balance = 0;
    for (final rtx in txs) {
      if (rtx.rrId == tx.srId && (rtx.isActive || rtx.isPartial)) {
        balance += rtx.balance;
      }
    }

    return balance;
  }

  Map<int, double> collectBranchActiveAmount(TransactionsModel tx) {
    final txs = _repo.collectDescendantLeaves(tx);

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
      load();
    } catch (e) {
      rethrow;
    }
  }

  List<String> getAllRateID() {
    List<String> ids = [];

    for (final tx in items) {
      ids.add("${tx.srId}-${tx.rrId}");
      ids.add("${tx.rrId}-${tx.srId}");
    }

    return ids;
  }
}
