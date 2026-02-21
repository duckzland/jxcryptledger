import 'package:hive_ce/hive_ce.dart';

import '../../core/filtering.dart';
import 'model.dart';

class TransactionsRepository {
  static const String boxName = 'transactions_box';

  final FilterIsolate _filter = FilterIsolate();

  Box<TransactionsModel> get _box => Hive.box<TransactionsModel>(boxName);

  Future<void> init() async {
    await _filter.init();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<TransactionsModel>(boxName);
    }
  }

  Future<void> add(TransactionsModel tx) async {
    await _box.put(tx.tid, tx);
  }

  Future<List<TransactionsModel>> getAll() async {
    final list = <TransactionsModel>[];
    for (final key in _box.keys) {
      final tx = _box.get(key);
      if (tx != null) list.add(tx);
    }
    return list;
  }

  Future<List<TransactionsModel>> filter(String query) async {
    final all = await getAll();
    final maps = all.map((e) => e.toMap()).toList();

    final filteredMaps = await _filter.filter(maps, query);
    return filteredMaps.map(TransactionsModel.fromMap).toList();
  }
}
