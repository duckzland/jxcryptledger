import 'package:hive_ce/hive_ce.dart';

import 'model.dart';

abstract class CoreBaseRepository<T extends BaseModel<K>, K> {
  String get boxName;
  Box<T> get box => Hive.box<T>(boxName);

  Future<void> add(T tx) async {
    await box.put(tx.uuid, tx);
    onAction();
  }

  Future<void> update(T tx) async {
    await box.put(tx.uuid, tx);
    onAction();
  }

  Future<void> delete(T tx) async {
    await box.delete(tx.uuid);
    onAction();
  }

  Future<int> clear() async {
    final count = await box.clear();
    onAction();
    return count;
  }

  Future<void> flush() async {
    await box.flush();
    onAction();
  }

  Future<T?> get(K id) async {
    return box.get(id);
  }

  Future<List<T>> getAll() async {
    return box.values.toList();
  }

  bool isEmpty() {
    return box.isEmpty;
  }

  void onAction() {}
}
