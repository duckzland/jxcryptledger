import 'dart:async';

import '../ipc/box.dart';
import '../ipc/event.dart';
import 'models/with_id.dart';

abstract class CoreBaseRepository<T extends CoreModelWithId> {
  String get boxName;
  bool initialized = false;

  CoreIpcBox<T>? repoBox;

  CoreIpcBox<T> get box {
    return repoBox ??= CoreIpcBox<T>(boxName);
  }

  set box(CoreIpcBox<T> box) {
    repoBox = box;
  }

  Future<void> init() async {
    if (initialized) {
      return;
    }

    await box.init();
    onAction();

    initialized = true;
  }

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

  Future<void> addAll(List<T> values) async {
    await box.addAll(values);
    onAction();
  }

  Future<void> replace(List<T> values) async {
    await box.replace(values);
    onAction();
  }

  List<T> extract() {
    return box.values.toList();
  }

  bool isEmpty() {
    return box.isEmpty;
  }

  void receive(CoreIpcBroadcastEvent event) {
    box.receive(event);
  }

  void onAction() {}
}
