import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

import '../../../app/exceptions.dart';
import '../../../core/abstracts/service.dart';
import '../../../core/log.dart';
import '../../../core/worker/job.dart';
import '../../../core/worker/processor.dart';
import '../../../system/settings/keys.dart';
import '../../../system/settings/repository.dart';
import '../markets/service.dart';
import 'mixins/helper.dart';
import 'model.dart';
import 'repository.dart';

class TickersService extends CoreBaseService<TickersModel, TickersRepository> with TickersMixinsHelper {
  final SettingsRepository settingsRepo;
  final MarketsService marketsService;
  final CoreWorkerProcessor worker = CoreWorkerProcessor();

  TickersService(super.repo, this.settingsRepo, this.marketsService);

  @override
  Future<void> init() async {
    await repo.init();
    if (repo.isEmpty() || repo.count() < 16) {
      await populate();
    }
    broadcasterListen();
  }

  Future<void> populate({bool fetchRate = true}) async {
    for (final tx in defaultTickers) {
      if (repo.get(tx.uuid) == null) {
        await repo.add(tx);
      }
    }

    if (fetchRate) {
      refreshRates();
    }
  }

  Future<Map<String, dynamic>> _fetchJson(SettingKey key, {Map<String, String>? query, http.Client? fetcher}) async {
    final endpoint = settingsRepo.getByKey<String>(key) ?? key.defaultValue;
    final uri = Uri.parse(endpoint).replace(queryParameters: query);
    final authKey = settingsRepo.getByKey<String>(SettingKey.authorizationKey);

    final isCustom = !endpoint.contains("coinmarketcap.com");
    final needAuth = isCustom || endpoint.contains("https://pro-api.coinmarketcap.com/v");

    final headers = <String, String>{};
    if (authKey != null && authKey.isNotEmpty && needAuth) {
      if (!isCustom) {
        headers['X-CMC_PRO_API_KEY'] = authKey;
      } else {
        headers['Authorization'] = authKey;
      }
    }

    final client = fetcher ?? http.Client();
    final http.Response resp;

    try {
      resp = await client.get(uri, headers: headers);
    } finally {
      if (fetcher == null) {
        client.close();
      }
    }

    if (resp.statusCode != 200) {
      throw NetworkingException(
        AppErrorCode.netHttpFailure,
        "Ticker fetch failed: HTTP [${resp.statusCode}][$uri]",
        "Unable to retrieve data from the server.",
        details: resp.statusCode,
      );
    }

    logln('[TICKERS] Fetching from : $uri [${resp.statusCode}]');

    try {
      return parseJson(resp.body);
    } catch (e) {
      logln('[TICKERS] FAILURE : ${resp.body}');
      throw NetworkingException(
        AppErrorCode.netParseFailure,
        "Ticker fetch failed: parse error",
        "The server returned invalid JSON data.",
        details: e,
      );
    }
  }

  Future<bool> fetchAltSeason(http.Client? fetcher) async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.altSeasonEndpoint) ?? SettingKey.altSeasonEndpoint.defaultValue;
    final isLegacy = endpoint.contains("data-api/v3/altcoin-season/chart");

    Map<String, String> query = {};

    if (isLegacy) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
      final end = DateTime(now.year, now.month + 1, 0).millisecondsSinceEpoch ~/ 1000;
      query = {"start": start.toString(), "end": end.toString()};
    }

    final body = await _fetchJson(SettingKey.altSeasonEndpoint, query: query, fetcher: fetcher);

    String index;

    if (isLegacy) {
      final nowObj = body["data"]["historicalValues"]["now"];
      index = nowObj["altcoinIndex"].toString();
    } else {
      index = body["data"]["altcoin_index"].toString();
    }

    repo.updateByType(TickerType.altcoinIndex.index, index);

    return true;
  }

  Future<bool> fetchFearGreed(http.Client? fetcher) async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.fearGreedEndpoint) ?? SettingKey.fearGreedEndpoint.defaultValue;
    final isLegacy = endpoint.contains("data-api/v3/fear-greed/chart");

    Map<String, String> query = {};

    if (isLegacy) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
      final end = DateTime(now.year, now.month + 1, 0).millisecondsSinceEpoch ~/ 1000;

      query = {"start": start.toString(), "end": end.toString()};
    }

    final body = await _fetchJson(SettingKey.fearGreedEndpoint, query: query, fetcher: fetcher);

    String score;
    if (isLegacy) {
      final nowObj = body["data"]["historicalValues"]["now"];
      score = nowObj["score"].toString();
    } else {
      score = body['data']['value'].toString();
    }

    repo.updateByType(TickerType.fearGreed.index, score);

    return true;
  }

  Future<bool> fetchCmc100(http.Client? fetcher) async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.cmc100Endpoint) ?? SettingKey.cmc100Endpoint.defaultValue;
    final isLegacy = endpoint.contains("data-api/v3/top100/supplement");

    Map<String, String> query = {};

    if (isLegacy) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
      final end = DateTime(now.year, now.month + 1, 0).millisecondsSinceEpoch ~/ 1000;

      query = {"start": start.toString(), "end": end.toString()};
    }

    final body = await _fetchJson(SettingKey.cmc100Endpoint, query: query, fetcher: fetcher);

    String value;
    if (isLegacy) {
      final summary = body["data"]["summaryData"]["currentValue"];
      value = summary["value"].toString();
    } else {
      value = body["data"]["value"].toString();
    }

    repo.updateByType(TickerType.cmc100.index, value);

    return true;
  }

  Future<bool> fetchMarketCap(http.Client? fetcher) async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.marketCapEndpoint) ?? SettingKey.marketCapEndpoint.defaultValue;
    final isLegacy = endpoint.contains("data-api/v4/global-metrics/quotes/historical");

    Map<String, String> query = isLegacy ? {"convertId": "2781", "range": "30d"} : {"convert": "USD", "aux": "btc_dominance"};

    final body = await _fetchJson(SettingKey.marketCapEndpoint, query: query, fetcher: fetcher);

    if (isLegacy) {
      final marketCap = body["data"]["historicalValues"]["now"]["marketCap"].toString();
      repo.updateByType(TickerType.marketCap.index, marketCap);
    } else {
      final marketCap = body["data"]["quote"]["USD"]["total_market_cap"].toString();
      repo.updateByType(TickerType.marketCap.index, marketCap);

      final dominanceBtc = body["data"]["btc_dominance"].toString();
      repo.updateByType(TickerType.dominance.index, dominanceBtc);
    }

    return true;
  }

  Future<bool> fetchRsi(http.Client? fetcher) async {
    final body = await _fetchJson(
      SettingKey.rsiEndpoint,
      query: {"timeframe": "4h", "rsiPeriod": "14", "volume24Range.min": "1000000", "marketCapRange.min": "50000000"},
      fetcher: fetcher,
    );

    final overall = body["data"]["overall"];
    final overBought = overall["overboughtPercentage"] != null ? Decimal.parse(overall["overboughtPercentage"].toString()) : Decimal.zero;
    final overSold = overall["oversoldPercentage"] != null ? Decimal.parse(overall["oversoldPercentage"].toString()) : Decimal.zero;

    final avgRsi = overall["averageRsi"].toString();
    final pulse = overBought - overSold;

    repo.updateByType(TickerType.rsi.index, avgRsi);
    repo.updateByType(TickerType.pulse.index, pulse.toString());

    return true;
  }

  Future<bool> fetchEtf(http.Client? fetcher) async {
    final body = await _fetchJson(SettingKey.etfEndpoint, query: {"category": "all", "range": "30d"}, fetcher: fetcher);

    // final total = body["data"]["total"].toString();
    // final btcValue = body["data"]["totalBtcValue"].toString();
    final ethValue = body["data"]["totalEthValue"].toString();

    repo.updateByType(TickerType.etf.index, ethValue);

    return true;
  }

  Future<bool> fetchDominance(http.Client? fetcher) async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.marketCapEndpoint) ?? SettingKey.marketCapEndpoint.defaultValue;
    final isLegacy = endpoint.contains("data-api/v4/global-metrics/quotes/historical");

    // New marketcap will populate the dominance!
    if (!isLegacy) {
      logln("Skipping dominance");
      return true;
    }

    final body = await _fetchJson(SettingKey.dominanceEndpoint, fetcher: fetcher);

    final dominanceList = body["data"]["dominance"] as List<dynamic>;
    final btc = dominanceList[0]["mcProportion"].toString();

    repo.updateByType(TickerType.dominance.index, btc);

    return true;
  }

  Future<bool> fetchMarketGainerLoser(http.Client? fetcher) async {
    if (marketsService.isEmpty()) {
      await marketsService.refreshRates();
    }

    final markets = marketsService.extract();

    final top100 = markets.where((m) => m.rank <= 100 && !m.isStableCoin).toList();

    final sorted100_1h = [...top100]..sort((a, b) => (b.percent1h ?? Decimal.zero).compareTo(a.percent1h ?? Decimal.zero));
    final gainer100_1h = sorted100_1h.first;
    final loser100_1h = sorted100_1h.last;

    final sorted100_24h = [...top100]..sort((a, b) => (b.percent24h ?? Decimal.zero).compareTo(a.percent24h ?? Decimal.zero));
    final gainer100_24h = sorted100_24h.first;
    final loser100_24h = sorted100_24h.last;

    final next100 = markets.where((m) => m.rank > 100 && m.rank <= 200 && !m.isStableCoin).toList();

    final sorted200_1h = [...next100]..sort((a, b) => (b.percent1h ?? Decimal.zero).compareTo(a.percent1h ?? Decimal.zero));
    final gainer200_1h = sorted200_1h.first;
    final loser200_1h = sorted200_1h.last;

    final sorted200_24h = [...next100]..sort((a, b) => (b.percent24h ?? Decimal.zero).compareTo(a.percent24h ?? Decimal.zero));
    final gainer200_24h = sorted200_24h.first;
    final loser200_24h = sorted200_24h.last;

    repo.updateByType(TickerType.topGainer100_1h.index, gainer100_1h.percent1hText, title: '${gainer100_1h.symbol} - 1h');
    repo.updateByType(TickerType.topGainer100_24h.index, gainer100_24h.percent24hText, title: '${gainer100_24h.symbol} - 24h');

    repo.updateByType(TickerType.topLoser100_1h.index, loser100_1h.percent1hText, title: '${loser100_1h.symbol} - 1h');
    repo.updateByType(TickerType.topLoser100_24h.index, loser100_24h.percent24hText, title: '${loser100_24h.symbol} - 24h');

    repo.updateByType(TickerType.topGainer200_1h.index, gainer200_1h.percent1hText, title: '${gainer200_1h.symbol} - 1h');
    repo.updateByType(TickerType.topGainer200_24h.index, gainer200_24h.percent24hText, title: '${gainer200_24h.symbol} - 24h');

    repo.updateByType(TickerType.topLoser200_1h.index, loser200_1h.percent1hText, title: '${loser200_1h.symbol} - 1h');
    repo.updateByType(TickerType.topLoser200_24h.index, loser200_24h.percent24hText, title: '${loser200_24h.symbol} - 24h');

    return true;
  }

  Future<void> refreshRates() async {
    final all = repo.extract();
    final types = all.map((tix) => TickerType.values[tix.type]).toSet();

    if (types.isEmpty) return;

    final jobs = <CoreWorkerJob>[];

    if (types.contains(TickerType.altcoinIndex)) {
      jobs.add(
        CoreWorkerJob(
          id: TickerType.altcoinIndex.index,
          payload: const [],
          callback: (_, _, {http.Client? fetcher}) async => await fetchAltSeason(fetcher),
          isFreePlan: false,
        ),
      );
    }
    if (types.contains(TickerType.fearGreed)) {
      jobs.add(
        CoreWorkerJob(
          id: TickerType.fearGreed.index,
          payload: const [],
          callback: (_, _, {http.Client? fetcher}) async => await fetchFearGreed(fetcher),
          isFreePlan: false,
        ),
      );
    }
    if (types.contains(TickerType.cmc100)) {
      jobs.add(
        CoreWorkerJob(
          id: TickerType.cmc100.index,
          payload: const [],
          callback: (_, _, {http.Client? fetcher}) async => await fetchCmc100(fetcher),
          isFreePlan: false,
        ),
      );
    }
    if (types.contains(TickerType.marketCap)) {
      jobs.add(
        CoreWorkerJob(
          id: TickerType.marketCap.index,
          payload: const [],
          callback: (_, _, {http.Client? fetcher}) async => await fetchMarketCap(fetcher),
          isFreePlan: false,
        ),
      );
    }
    if (types.contains(TickerType.dominance)) {
      jobs.add(
        CoreWorkerJob(
          id: TickerType.dominance.index,
          payload: const [],
          callback: (_, _, {http.Client? fetcher}) async => await fetchDominance(fetcher),
          isFreePlan: false,
        ),
      );
    }
    if (types.contains(TickerType.etf)) {
      jobs.add(
        CoreWorkerJob(
          id: TickerType.etf.index,
          payload: const [],
          callback: (_, _, {http.Client? fetcher}) async => await fetchEtf(fetcher),
          isFreePlan: false,
        ),
      );
    }
    if (types.contains(TickerType.pulse)) {
      jobs.add(
        CoreWorkerJob(
          id: TickerType.pulse.index,
          payload: const [],
          callback: (_, _, {http.Client? fetcher}) async => await fetchRsi(fetcher),
          isFreePlan: false,
        ),
      );
    }

    const mgmlTypes = {
      TickerType.topGainer100_1h,
      TickerType.topGainer100_24h,
      TickerType.topGainer200_1h,
      TickerType.topGainer200_24h,
      TickerType.topLoser100_1h,
      TickerType.topLoser100_24h,
      TickerType.topLoser200_1h,
      TickerType.topLoser200_24h,
    };

    if (types.any(mgmlTypes.contains)) {
      jobs.add(
        CoreWorkerJob(
          id: 999,
          payload: const [],
          callback: (_, _, {http.Client? fetcher}) async => await fetchMarketGainerLoser(fetcher),
          isFreePlan: false,
        ),
      );
    }

    try {
      await worker.run(jobs);
    } finally {
      logln("[TICKERS] Fetching new ticker data completed");
    }
  }

  Map<String, dynamic> parseJson(String body) {
    return json.decode(body) as Map<String, dynamic>;
  }
}
