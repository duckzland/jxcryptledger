import 'dart:async';
import 'package:flutter/material.dart';

import 'model.dart';
import 'repository.dart';

abstract class CoreBaseController<T extends CoreBaseModel<K>, K, R extends CoreBaseRepository<T, K>> extends ChangeNotifier {
  List<T> listItems = [];
  List<T> get items => listItems;

  final R repo;

  CoreBaseController(this.repo);

  void init() {
    load();
  }

  void start() {
    listItems = repo.getAll();
  }

  void load() {
    start();
    notifyListeners();
  }

  T? get(K tid) {
    final tx = repo.get(tid);
    return tx;
  }

  List<T> all() {
    return repo.getAll();
  }

  List<T> extract() {
    return items;
  }

  Future<void> add(T tx) async {
    await repo.add(tx);
    load();
  }

  Future<void> update(T tx) async {
    await repo.update(tx);
    load();
  }

  Future<void> delete(T tx) async {
    await repo.delete(tx);
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
}
