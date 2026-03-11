import 'package:flutter/foundation.dart';

import '../../core/log.dart';
import '../rates/service.dart';
import 'model.dart';
import 'repository.dart';

class WatchersController extends ChangeNotifier {
  final WatchersRepository _repo;
  final RatesService _ratesService;

  List<WatchersModel> _items = [];
  List<WatchersModel> get items => _items;

  WatchersController(this._repo, this._ratesService);

  String generateWid() {
    return _repo.generateWid();
  }

  Future<void> load() async {
    _items = await _repo.getAll();
    notifyListeners();
  }

  Future<void> init() async {
    for (final wx in items) {
      _ratesService.addQueue(wx.srId, wx.rrId);
    }
    notifyListeners();
  }

  Future<void> add(WatchersModel watcher) async {
    _ratesService.addQueue(watcher.srId, watcher.rrId);
    await _repo.add(watcher);
    await load();
  }

  Future<void> update(WatchersModel watcher) async {
    _ratesService.addQueue(watcher.srId, watcher.rrId);
    await _repo.update(watcher);
    await load();
  }

  Future<void> delete(WatchersModel watcher) async {
    await _ratesService.delete(watcher.srId, watcher.rrId);
    await _repo.delete(watcher.wid);
    await load();
  }

  Future<void> deleteAll() async {
    for (final wx in items) {
      await _ratesService.delete(wx.srId, wx.rrId);
    }
    await _repo.clear();
    await load();
  }

  WatchersModel? getLinked(String linkKey) {
    for (final wx in items) {
      if (wx.meta['txLink'] == linkKey) {
        return wx;
      }
    }

    return null;
  }

  bool isEmpty() {
    return _repo.isEmpty();
  }

  Future<void> onRatesUpdated() async {
    await load();
    for (final w in _items) {
      logln("[Watcher] Evaluating ${w.srId}-${w.rrId}");
      _repo.process(w);
    }
  }

  Future<void> sendNotification(WatchersModel wx) async {
    await _repo.sendNotification(wx);
  }

  Future<String> exportDatabase() async {
    try {
      return await _repo.export();
    } catch (e) {
      return '';
    }
  }

  Future<void> importDatabase(String rawJson) async {
    try {
      await _repo.import(rawJson);
      await load();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> restart() async {
    for (final wx in _items) {
      final resetWx = wx.copyWith(sent: 0, timestamp: 0);
      await _repo.update(resetWx);
    }

    await load();
  }

  bool hasRestartable() {
    for (final wx in _items) {
      if (wx.sent >= wx.limit) {
        return true;
      }
    }
    return false;
  }
}
