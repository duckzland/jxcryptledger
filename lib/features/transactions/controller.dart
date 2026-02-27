import 'package:flutter/foundation.dart';

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
      rethrow;
    }
  }

  Future<bool> isClosable(TransactionsModel tx) async {
    try {
      return repo.canClose(tx);
    } catch (e) {
      rethrow;
    }
  }
}
