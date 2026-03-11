import 'package:flutter/foundation.dart';

import '../../../core/log.dart';
import '../../rates/service.dart';
import '../../transactions/repository.dart';
import 'model.dart';
import 'repository.dart';

class PanelsController extends ChangeNotifier {
  final PanelsRepository _repo;
  final TransactionsRepository _txRepo;
  final RatesService _ratesService;

  List<PanelsModel> _items = [];
  List<PanelsModel> get items => _items;

  PanelsController(this._repo, this._ratesService, this._txRepo);

  String generateTid() {
    return _repo.generateTid();
  }

  Future<void> init() async {
    scheduleRates();
  }

  Future<void> load() async {
    _items = await _repo.getAll();
    notifyListeners();
  }

  Future<PanelsModel?> get(String tid) async {
    final tx = await _repo.get(tid);
    await load();
    return tx;
  }

  Future<void> add(PanelsModel tx) async {
    await _repo.add(tx);
    await load();
  }

  Future<void> update(PanelsModel tx) async {
    await _repo.update(tx);
    await load();
  }

  Future<void> delete(PanelsModel tx) async {
    await _repo.delete(tx);
    await load();
  }

  Future<void> wipe() async {
    await _repo.clear();
    await load();
  }

  Future<void> scheduleRates() async {
    await load();
    for (final w in _items) {
      _ratesService.addQueue(w.srId, w.rrId);
    }

    logln("[PANELS] Scheduling rates completed");
  }

  Future<void> onRatesUpdated() async {
    await load();
    for (final w in _items) {
      logln("[Tickers] Evaluating ${w.srId}-${w.rrId}");
      final newRate = await _ratesService.getStoredRate(w.srId, w.rrId);

      if (newRate == -9999) {
        _ratesService.addQueue(w.srId, w.rrId);
        continue;
      }

      if (newRate != w.rate) {
        w.setRate(newRate);
        update(w);
      }
    }
  }

  PanelsModel? getLinked(String linkKey) {
    for (final wx in items) {
      if (wx.meta['txLink'] == linkKey) {
        return wx;
      }
    }

    return null;
  }

  bool hasLinked() {
    for (final wx in items) {
      if (wx.meta['txLink'] != null && wx.meta['txLink'] != "") {
        return true;
      }
    }

    return false;
  }

  int nextHighestOrder() {
    int maxOrder = 0;

    for (final wx in items) {
      final raw = wx.order;

      if (raw != null) {
        final value = raw;
        if (value > maxOrder) {
          maxOrder = value;
        }
      }
    }

    return maxOrder + 1;
  }

  Future<bool> updateLinked() async {
    final txs = await _txRepo.getAll();
    final Map<String, double> grouped = {};
    int updateCount = 0;

    for (final tx in txs) {
      final pairKey = "${tx.srId}-${tx.rrId}";
      grouped[pairKey] = (grouped[pairKey] ?? 0.0) + tx.srAmount;
    }

    for (final wx in items) {
      final txlink = wx.meta['txLink'] ?? "";
      if (txlink.isEmpty) {
        continue;
      }

      if (txlink.contains("active-screen-")) {
        final regex = RegExp(r'active-screen-(\d+)-(\d+)');
        final match = regex.firstMatch(txlink);

        if (match != null) {
          final srid = match.group(1);
          final rrid = match.group(2);
          final pairKey = "$srid-$rrid";
          final totalAmount = grouped[pairKey] ?? 0.0;

          if (wx.srAmount != totalAmount) {
            final nwx = wx.copyWith(srAmount: totalAmount);
            update(nwx);
            updateCount += 1;
          }
        }
      }
    }

    return updateCount > 0;
  }

  Future<void> wipeLinked() async {
    for (final wx in items) {
      final txlink = wx.meta['txLink'] ?? "";
      if (txlink.isEmpty) {
        continue;
      }

      await delete(wx);
    }

    await load();
  }

  bool isEmpty() {
    return _repo.isEmpty();
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

  void updateOrder(List<PanelsModel> newOrder) {
    for (var i = 0; i < newOrder.length; i++) {
      newOrder[i].order = i;
      _repo.update(newOrder[i]);
    }

    load();
  }
}
