import 'dart:async';
import 'package:flutter/material.dart';

import 'models/with_id.dart';
import 'repository.dart';

abstract class CoreBaseController<T extends CoreModelWithId, R extends CoreBaseRepository<T>> extends ChangeNotifier {
  List<T> listItems = [];
  List<T> get items => listItems;

  final R repo;

  CoreBaseController(this.repo);

  void init() {
    load();
  }

  void start() {
    listItems = repo.extract();
  }

  void load() {
    start();
    notifyListeners();
  }

  T? get(String tid) {
    return repo.get(tid);
  }

  List<T> extract() {
    return repo.extract();
  }

  Future<void> add(T tx) async {
    await repo.add(tx);
    load();
  }

  Future<void> update(T tx) async {
    await repo.update(tx);
    load();
  }

  Future<void> remove(T tx) async {
    await repo.remove(tx);
    load();
  }

  Future<void> delete(String id) async {
    await repo.delete(id);
    load();
  }

  Future<void> flush() async {
    await repo.flush();
    load();
  }

  Future<void> clear() async {
    await repo.clear();
    load();
  }

  Future<bool> wipe() async {
    try {
      final removed = await repo.clear();
      load();
      return removed != 0;
    } catch (e) {
      return false;
    }
  }

  bool isEmpty() {
    return repo.isEmpty();
  }

  T? findNew(List<T> oldItems) {
    final oldIds = oldItems.map((t) => t.uuid).toSet();
    final addedIds = items.map((t) => t.uuid).where((id) => !oldIds.contains(id));

    if (addedIds.isEmpty) {
      return null;
    }

    return items.firstWhere((el) => el.uuid == addedIds.first);
  }
}
