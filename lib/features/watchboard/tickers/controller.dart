import '../../../core/abstracts/controller.dart';
import '../../../core/mixins/controllers/id_generator.dart';
import 'model.dart';
import 'repository.dart';
import 'service.dart';

class TickersController extends CoreBaseController<TickersModel, String, TickersRepository>
    with CoreMixinsControllersIdGenerator<TickersModel, String, TickersRepository> {
  final TickersService _service;

  TickersController(super.repo, this._service);

  @override
  void init() {
    if (isEmpty()) {
      populate();
    }
  }

  Future<void> updateByType(int type, String newVal) async {
    await repo.updateByType(type, newVal);
    load();
  }

  Future<void> populate() async {
    final tickers = [
      TickersModel(
        tid: repo.generateId(),
        type: TickerType.marketCap.index,
        format: TickerFormat.shortCurrency.index,
        title: "Market Cap",
        order: 0,
      ),
      TickersModel(
        tid: repo.generateId(),
        type: TickerType.pulse.index,
        format: TickerFormat.shortPercentageWithSign.index,
        title: "Market Bias",
        order: 1,
      ),
      TickersModel(
        tid: repo.generateId(),
        type: TickerType.cmc100.index,
        format: TickerFormat.normalCurrency.index,
        title: "CMC100",
        order: 2,
      ),
      TickersModel(
        tid: repo.generateId(),
        type: TickerType.altcoinIndex.index,
        format: TickerFormat.percentage.index,
        title: "Altcoin Index",
        order: 3,
      ),
      TickersModel(
        tid: repo.generateId(),
        type: TickerType.fearGreed.index,
        format: TickerFormat.percentage.index,
        title: "Fear & Greed",
        order: 4,
      ),
      TickersModel(
        tid: repo.generateId(),
        type: TickerType.rsi.index,
        format: TickerFormat.normalNumber.index,
        title: "Crypto RSI",
        order: 5,
      ),
      TickersModel(
        tid: repo.generateId(),
        type: TickerType.etf.index,
        format: TickerFormat.shortCurrencyWithSign.index,
        title: "ETF Flow",
        order: 6,
      ),
      TickersModel(
        tid: repo.generateId(),
        type: TickerType.dominance.index,
        format: TickerFormat.shortPercentage.index,
        title: "Dominance",
        order: 7,
      ),
    ];

    for (final tx in tickers) {
      await repo.add(tx);
    }

    load();

    _service.refreshRates();
  }

  Future<void> refreshRates() async {
    await _service.refreshRates();
    load();
  }

  void updateOrder(List<TickersModel> newOrder) {
    for (var i = 0; i < newOrder.length; i++) {
      newOrder[i].order = i;
      repo.update(newOrder[i]);
    }

    load();
  }
}
