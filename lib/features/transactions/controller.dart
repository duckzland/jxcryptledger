import 'package:flutter/foundation.dart';
import 'model.dart';
import 'repository.dart';

class TransactionsController extends ChangeNotifier {
  final TransactionRepository repo;

  List<TransactionModel> _items = [];
  List<TransactionModel> get items => _items;

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

  Future<void> add(TransactionModel tx) async {
    await repo.add(tx);
    await load();
  }
}
