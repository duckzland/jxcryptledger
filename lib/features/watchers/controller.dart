import 'package:flutter/foundation.dart';

import '../../core./locator.dart';
import '../../core/log.dart';
import '../rates/controller.dart';
import 'model.dart';
import 'repository.dart';

class WatchersController extends ChangeNotifier {
  final WatchersRepository repo;
  final rates = locator<RatesController>();

  List<WatchersModel> _items = [];
  List<WatchersModel> get items => _items;

  WatchersController(this.repo);

  String generateWid() {
    return repo.generateWid();
  }

  Future<void> load() async {
    _items = await repo.getAll();
    notifyListeners();
  }

  Future<void> init() async {
    for (final wx in items) {
      rates.addQueue(wx.srId, wx.rrId);
    }
    notifyListeners();
  }

  Future<void> add(WatchersModel watcher) async {
    rates.addQueue(watcher.srId, watcher.rrId);
    await repo.add(watcher);
    await load();
  }

  Future<void> update(WatchersModel watcher) async {
    rates.addQueue(watcher.srId, watcher.rrId);
    await repo.update(watcher);
    await load();
  }

  Future<void> delete(WatchersModel watcher) async {
    await rates.delete(watcher.srId, watcher.rrId);
    await repo.delete(watcher.wid);
    await load();
  }

  Future<void> deleteAll() async {
    for (final wx in items) {
      await rates.delete(wx.srId, wx.rrId);
    }
    await repo.clear();
    await load();
  }

  bool isEmpty() {
    return repo.isEmpty();
  }

  Future<void> onRatesUpdated() async {
    await load();
    for (final w in _items) {
      logln("[Watcher] Evaluating ${w.srId}-${w.rrId}");
      repo.evaluateWatcher(w);
    }
  }
}
