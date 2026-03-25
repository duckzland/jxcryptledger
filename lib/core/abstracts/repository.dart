import 'dart:async';

import 'package:hive_ce/hive_ce.dart';

import 'model.dart';

abstract class CoreBaseRepository<T extends CoreBaseModel<K>, K> {
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

  FutureOr<T?> getAsync(K id) {
    return box.get(id);
  }

  FutureOr<List<T>> getAllAsync() {
    return box.values.toList();
  }

  T? get(K id) {
    return box.get(id);
  }

  List<T> getAll() {
    return box.values.toList();
  }

  bool isEmpty() {
    return box.isEmpty;
  }

  void onAction() {}
}
