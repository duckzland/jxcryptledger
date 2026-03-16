import 'package:flutter/foundation.dart';

import '../../core/log.dart';
import '../../core/utils.dart';
import '../cryptos/service.dart';
import '../notification/service.dart';
import '../rates/service.dart';
import 'model.dart';
import 'repository.dart';

class WatchersController extends ChangeNotifier {
  final WatchersRepository _repo;
  final RatesService _ratesService;
  final NotificationService _notificationService;
  final CryptosService _cryptosService;

  List<WatchersModel> _items = [];
  List<WatchersModel> get items => _items;

  WatchersController(this._repo, this._ratesService, this._notificationService, this._cryptosService);

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
    await _ratesService.delete(watcher.rrId, watcher.srId);
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
    for (final w in items) {
      logln("[WATCHER] Evaluating ${w.srId}-${w.rrId}");
      process(w);
    }
  }

  Future<void> process(WatchersModel wx) async {
    if (wx.isSpent()) return;

    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final last = Utils.sanitizeTimestamp(wx.timestamp);
    final nextAllowed = last + (wx.duration * 60000000);
    if (now < nextAllowed) return;

    final current = await _ratesService.getStoredRate(wx.srId, wx.rrId);
    if (current == -9999) {
      _ratesService.addQueue(wx.srId, wx.rrId);
      return;
    }

    switch (wx.operatorEnum) {
      case WatchersOperator.equal:
        if (current != wx.rates) return;
      case WatchersOperator.lessThan:
        if (current >= wx.rates) return;
      case WatchersOperator.greaterThan:
        if (current <= wx.rates) return;
    }

    final updated = wx.copyWith(sent: wx.sent + 1, timestamp: now);

    await _repo.update(updated);
    await load();

    await sendNotification(wx);
  }

  Future<void> sendNotification(WatchersModel wx) async {
    String message = wx.message;
    if (message == "" || message.trim().isEmpty) {
      final sourceSymbol = _cryptosService.getSymbol(wx.srId) ?? "";
      final targetSymbol = _cryptosService.getSymbol(wx.rrId) ?? "";

      message = "$sourceSymbol to $targetSymbol is ${wx.operatorMessage} ${wx.rates}.";
    }

    await _notificationService.show(message);
  }

  Future<String> exportDatabase() async {
    return await _repo.export();
  }

  Future<void> importDatabase(String rawJson) async {
    await _repo.import(rawJson);
    await load();
  }

  Future<void> restart() async {
    for (final wx in _items) {
      final resetWx = wx.copyWith(sent: 0, timestamp: 0);
      await _repo.update(resetWx);
    }

    await load();
  }

  bool hasRestartable() {
    for (final wx in items) {
      if (wx.sent >= wx.limit) {
        return true;
      }
    }
    return false;
  }
}
