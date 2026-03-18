import 'package:flutter/foundation.dart';
import 'package:jxledger/features/watchboard/tickers/service.dart';

import 'model.dart';
import 'repository.dart';

class TickersController extends ChangeNotifier {
  final TickersRepository _repo;
  final TickersService _service;

  List<TickersModel> _items = [];
  List<TickersModel> get items => _items;

  TickersController(this._repo, this._service);

  String generateTid() {
    return _repo.generateId();
  }

  Future<void> init() async {
    if (isEmpty()) {
      populate();
    }
  }

  Future<List<TickersModel>> getAll() async {
    return await _repo.getAll();
  }

  Future<void> load() async {
    _items = await _repo.getAll();
    notifyListeners();
  }

  Future<TickersModel?> get(String tid) async {
    final tx = await _repo.get(tid);
    await load();
    return tx;
  }

  Future<void> add(TickersModel tx) async {
    await _repo.add(tx);
    await load();
  }

  Future<void> update(TickersModel tx) async {
    await _repo.update(tx);
    await load();
  }

  Future<void> delete(TickersModel tx) async {
    await _repo.delete(tx);
    await load();
  }

  Future<void> wipe() async {
    await _repo.clear();
    await load();
  }

  bool isEmpty() {
    return _repo.isEmpty();
  }

  Future<void> updateByType(int type, String newVal) async {
    await _repo.updateByType(type, newVal);
    await load();
  }

  Future<void> populate() async {
    final tickers = [
      TickersModel(
        tid: _repo.generateId(),
        type: TickerType.marketCap.index,
        format: TickerFormat.shortCurrency.index,
        title: "Market Cap",
        order: 0,
      ),
      TickersModel(
        tid: _repo.generateId(),
        type: TickerType.pulse.index,
        format: TickerFormat.shortPercentageWithSign.index,
        title: "Market Bias",
        order: 1,
      ),
      TickersModel(
        tid: _repo.generateId(),
        type: TickerType.cmc100.index,
        format: TickerFormat.normalCurrency.index,
        title: "CMC100",
        order: 2,
      ),
      TickersModel(
        tid: _repo.generateId(),
        type: TickerType.altcoinIndex.index,
        format: TickerFormat.percentage.index,
        title: "Altcoin Index",
        order: 3,
      ),
      TickersModel(
        tid: _repo.generateId(),
        type: TickerType.fearGreed.index,
        format: TickerFormat.percentage.index,
        title: "Fear & Greed",
        order: 4,
      ),
      TickersModel(
        tid: _repo.generateId(),
        type: TickerType.rsi.index,
        format: TickerFormat.normalNumber.index,
        title: "Crypto RSI",
        order: 5,
      ),
      TickersModel(
        tid: _repo.generateId(),
        type: TickerType.etf.index,
        format: TickerFormat.shortCurrencyWithSign.index,
        title: "ETF Flow",
        order: 6,
      ),
      TickersModel(
        tid: _repo.generateId(),
        type: TickerType.dominance.index,
        format: TickerFormat.shortPercentage.index,
        title: "Dominance",
        order: 7,
      ),
    ];

    for (final tx in tickers) {
      await _repo.add(tx);
    }

    await load();
  }

  Future<void> refreshRates() async {
    await _service.refreshRates();
    await load();
  }

  void updateOrder(List<TickersModel> newOrder) {
    for (var i = 0; i < newOrder.length; i++) {
      newOrder[i].order = i;
      _repo.update(newOrder[i]);
    }

    load();
  }
}
