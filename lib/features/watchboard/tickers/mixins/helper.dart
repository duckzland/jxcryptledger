import '../model.dart';

mixin TickersMixinsHelper {
  final List<TickersModel> defaultTickers = [
    TickersModel(
      tid: "market_cap",
      type: TickerType.marketCap.index,
      format: TickerFormat.shortCurrency.index,
      title: "Market Cap",
      order: 0,
    ),
    TickersModel(
      tid: "market_bias",
      type: TickerType.pulse.index,
      format: TickerFormat.shortPercentageWithSign.index,
      title: "Market Bias",
      order: 1,
    ),
    TickersModel(tid: "cmc100", type: TickerType.cmc100.index, format: TickerFormat.normalCurrency.index, title: "CMC100", order: 2),
    TickersModel(
      tid: "altcoin_index",
      type: TickerType.altcoinIndex.index,
      format: TickerFormat.percentage.index,
      title: "Altcoin Index",
      order: 3,
    ),
    TickersModel(
      tid: "fear_greed",
      type: TickerType.fearGreed.index,
      format: TickerFormat.percentage.index,
      title: "Fear & Greed",
      order: 4,
    ),
    TickersModel(tid: "crypto_rsi", type: TickerType.rsi.index, format: TickerFormat.normalNumber.index, title: "Crypto RSI", order: 5),
    TickersModel(
      tid: "etf_flow",
      type: TickerType.etf.index,
      format: TickerFormat.shortCurrencyWithSign.index,
      title: "ETF Flow",
      order: 6,
    ),
    TickersModel(
      tid: "dominance",
      type: TickerType.dominance.index,
      format: TickerFormat.shortPercentage.index,
      title: "Dominance",
      order: 7,
    ),
  ];
}
