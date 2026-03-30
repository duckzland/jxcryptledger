import 'dart:async';
import 'package:hive_ce/hive_ce.dart';

import 'models/with_id.dart';

abstract class CoreBaseRepository<T extends CoreModelWithId> {
  String get boxName;
  Box<T> get box => Hive.box<T>(boxName);

  T? get(String id) {
    return box.get(id);
  }

  Future<void> add(T tx) async {
    await box.put(tx.uuid, tx);
    onAction();
  }

  Future<void> update(T tx) async {
    await box.put(tx.uuid, tx);
    onAction();
  }

  Future<void> remove(T tx) async {
    await box.delete(tx.uuid);
    onAction();
  }

  Future<void> delete(String id) async {
    await box.delete(id);
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

  List<T> extract() {
    return box.values.cast<T>().toList();
  }

  bool isEmpty() {
    return box.isEmpty;
  }

  void onAction() {}
}
