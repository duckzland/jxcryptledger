import 'dart:async';
import 'package:flutter/material.dart';

import 'models/base.dart';
import 'repository.dart';

abstract class CoreBaseController<T extends CoreModelBase<K>, K, R extends CoreBaseRepository<T, K>> extends ChangeNotifier {
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

  T? get(K tid) {
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

  Future<void> delete(K id) async {
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
}
