import 'package:flutter/foundation.dart';

import '../../core/log.dart';
import '../rates/controller.dart';
import 'model.dart';
import 'repository.dart';

class PanelsController extends ChangeNotifier {
  final PanelsRepository repo;
  final RatesController ratesController;

  List<PanelsModel> _items = [];
  List<PanelsModel> get items => _items;

  PanelsController(this.repo, this.ratesController);

  String generateTid() {
    return repo.generateTid();
  }

  Future<void> init() async {
    scheduleRates();
  }

  Future<void> load() async {
    _items = await repo.getAll();
    notifyListeners();
  }

  Future<PanelsModel?> get(String tid) async {
    final tx = await repo.get(tid);
    await load();
    return tx;
  }

  Future<void> add(PanelsModel tx) async {
    await repo.add(tx);
    await load();
  }

  Future<void> update(PanelsModel tx) async {
    await repo.update(tx);
    await load();
  }

  Future<void> delete(PanelsModel tx) async {
    await repo.delete(tx);
    await load();
  }

  Future<void> wipe() async {
    await repo.clear();
  }

  Future<void> scheduleRates() async {
    await load();
    for (final w in _items) {
      ratesController.addQueue(w.srId, w.rrId);
    }
  }

  Future<void> onRatesUpdated() async {
    await load();
    for (final w in _items) {
      logln("[Tickers] Evaluating ${w.srId}-${w.rrId}");
      final newRate = await ratesController.getStoredRate(w.srId, w.rrId);

      if (newRate == -9999) {
        ratesController.addQueue(w.srId, w.rrId);
        continue;
      }

      if (newRate != w.rate) {
        w.setRate(newRate);
        update(w);
      }
    }
  }

  bool isEmpty() {
    return repo.isEmpty();
  }

  Future<String> exportDatabase() async {
    try {
      return await repo.export();
    } catch (e) {
      return '';
    }
  }

  Future<void> importDatabase(String rawJson) async {
    try {
      await repo.import(rawJson);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  void updateOrder(List<PanelsModel> newOrder) {
    for (var i = 0; i < newOrder.length; i++) {
      newOrder[i].order = i;
      repo.update(newOrder[i]);
    }

    load();
  }
}
