import '../../app/exceptions.dart';
import '../../core/abstracts/controller.dart';
import '../../core/mixins/controllers/exportable.dart';
import '../../core/mixins/controllers/id_generator.dart';
import '../../core/mixins/controllers/rateable.dart';
import '../rates/service.dart';
import 'model.dart';
import 'repository.dart';

class TransactionsController extends CoreBaseController<TransactionsModel, TransactionsRepository>
    with
        CoreMixinsControllersIdGenerator<TransactionsModel, TransactionsRepository>,
        CoreMixinsControllersExportable<TransactionsModel, TransactionsRepository>,
        CoreMixinsControllersRateable<TransactionsModel, TransactionsRepository> {
  final RatesService _ratesService;

  TransactionsController(super.repo, this._ratesService);

  @override
  Future<void> remove(TransactionsModel tx) async {
    await _ratesService.delete(tx.srId, tx.rrId);
    await _ratesService.delete(tx.rrId, tx.srId);
    await repo.remove(tx);
    load();
  }

  Future<void> closeLeaf(TransactionsModel tx) async {
    await repo.close(tx);
    load();
  }

  TransactionsModel? getParent(TransactionsModel tx) {
    return repo.get(tx.pid);
  }

  Future<void> removeRoot(TransactionsModel tx) async {
    await repo.remove(tx);
    load();
  }

  Future<void> removeLeaf(TransactionsModel tx) async {
    await repo.refund(tx);
    load();
  }

  Future<void> deleteAll() async {
    final roots = repo.collectAllRoots();

    for (final tx in roots) {
      final bool deletable;
      try {
        deletable = isDeletable(tx);
      } catch (_) {
        continue;
      }

      if (!deletable) continue;

      await repo.remove(tx);
    }

    load();
  }

  Future<void> closeAll() async {
    final leaves = repo.collectAllTerminalLeaves();

    for (final tx in leaves) {
      final bool closable;
      try {
        closable = isClosable(tx);
      } catch (_) {
        continue;
      }

      if (!closable) continue;

      await repo.close(tx);
    }

    load();
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

  bool isClosedTerminals(TransactionsModel tx) {
    final leaves = repo.collectTerminalLeaves(tx);

    for (final ltx in leaves) {
      if (!ltx.isClosed) {
        return false;
      }
    }

    return true;
  }

  double getCapitalBalance(TransactionsModel tx) {
    final children = repo.getLeaf(tx);
    final double spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final double balance = tx.rrAmount - spent;

    return balance;
  }

  List<TransactionsModel> collectAllRoots() {
    return repo.collectAllRoots();
  }

  double collectAllTerminalResultAmount(TransactionsModel tx) {
    double balance = 0;
    final leaves = repo.collectAllTerminalLeaves();

    for (final ltx in leaves) {
      if (ltx.rrId == tx.rrId && ltx.isActive) {
        balance += ltx.balance;
      }
    }
    return balance;
  }

  double collectBranchTotalResultAmount(TransactionsModel tx) {
    final txs = repo.collectAllLeaves(tx);
    double balance = 0;
    for (final rtx in txs) {
      if (rtx.rrId == tx.srId && (rtx.isActive || rtx.isPartial)) {
        balance += rtx.balance;
      }
    }

    return balance;
  }

  Map<int, double> collectBranchActiveAmount(TransactionsModel tx) {
    final txs = repo.collectAllLeaves(tx);

    final Map<int, double> branchAmounts = {};

    for (final rtx in txs) {
      if ((rtx.isActive || rtx.isPartial) && rtx.tid != tx.tid) {
        final key = rtx.rrId;
        branchAmounts[key] = (branchAmounts[key] ?? 0) + rtx.balance;
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
}
