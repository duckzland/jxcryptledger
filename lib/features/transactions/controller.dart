import 'package:flutter/foundation.dart';

import '../../app/exceptions.dart';
import 'model.dart';
import 'repository.dart';

class TransactionsController extends ChangeNotifier {
  final TransactionsRepository repo;

  List<TransactionsModel> _items = [];
  List<TransactionsModel> get items => _items;

  TransactionsController(this.repo);

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

  Future<bool> hasLeaf(TransactionsModel tx) async {
    try {
      final leaf = await repo.getLeaf(tx);
      return leaf.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isAddable(TransactionsModel tx) async {
    try {
      await repo.canAdd(tx);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isClosable(TransactionsModel tx) async {
    try {
      await repo.canClose(tx);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isDeletable(TransactionsModel tx) async {
    try {
      await repo.canDelete(tx);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isUpdatable(TransactionsModel tx) async {
    try {
      await repo.canUpdate(tx);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isTradable(TransactionsModel tx) async {
    try {
      await repo.canTrade(tx);
      return true;
    } on ValidationException catch (_) {
      return false;
    } catch (e) {
      return false;
    }
  }
}
