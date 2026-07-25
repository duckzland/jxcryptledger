import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../app/exceptions.dart';
import '../../../core/abstracts/service.dart';
import '../../../core/log.dart';
import '../../../system/settings/keys.dart';
import '../../../system/settings/repository.dart';
import 'mixins/helper.dart';
import 'model.dart';
import 'repository.dart';

class TickersService extends CoreBaseService<TickersModel, TickersRepository> with TickersMixinsHelper {
  final SettingsRepository settingsRepo;

  TickersService(super.repo, this.settingsRepo);

  @override
  Future<void> init() async {
    repo.init();
    if (repo.isEmpty()) {
      await populate();
    }
    broadcasterListen();
  }

  Future<void> populate({bool fetchRate = true}) async {
    for (final tx in defaultTickers) {
      await repo.add(tx);
    }

    if (fetchRate) {
      refreshRates();
    }
  }

  Future<Map<String, dynamic>> _fetchJson(SettingKey key, {Map<String, String>? query}) async {
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

    final resp = await http.get(uri, headers: headers);
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

  Future<bool> fetchAltSeason() async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.altSeasonEndpoint) ?? SettingKey.altSeasonEndpoint.defaultValue;
    final isLegacy = endpoint.contains("data-api/v3/altcoin-season/chart");

    Map<String, String> query = {};

    if (isLegacy) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
      final end = DateTime(now.year, now.month + 1, 0).millisecondsSinceEpoch ~/ 1000;
      query = {"start": start.toString(), "end": end.toString()};
    }

    final body = await _fetchJson(SettingKey.altSeasonEndpoint, query: query);

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

  Future<bool> fetchFearGreed() async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.fearGreedEndpoint) ?? SettingKey.fearGreedEndpoint.defaultValue;
    final isLegacy = endpoint.contains("data-api/v3/fear-greed/chart");

    Map<String, String> query = {};

    if (isLegacy) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
      final end = DateTime(now.year, now.month + 1, 0).millisecondsSinceEpoch ~/ 1000;

      query = {"start": start.toString(), "end": end.toString()};
    }

    final body = await _fetchJson(SettingKey.fearGreedEndpoint, query: query);

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

  Future<bool> fetchCmc100() async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.cmc100Endpoint) ?? SettingKey.cmc100Endpoint.defaultValue;
    final isLegacy = endpoint.contains("data-api/v3/top100/supplement");

    Map<String, String> query = {};

    if (isLegacy) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
      final end = DateTime(now.year, now.month + 1, 0).millisecondsSinceEpoch ~/ 1000;

      query = {"start": start.toString(), "end": end.toString()};
    }

    final body = await _fetchJson(SettingKey.cmc100Endpoint, query: query);

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

  Future<bool> fetchMarketCap() async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.marketCapEndpoint) ?? SettingKey.marketCapEndpoint.defaultValue;
    final isLegacy = endpoint.contains("data-api/v4/global-metrics/quotes/historical");

    Map<String, String> query = isLegacy ? {"convertId": "2781", "range": "30d"} : {"convert": "USD", "aux": "btc_dominance"};

    final body = await _fetchJson(SettingKey.marketCapEndpoint, query: query);

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

  Future<bool> fetchRsi() async {
    final body = await _fetchJson(
      SettingKey.rsiEndpoint,
      query: {"timeframe": "4h", "rsiPeriod": "14", "volume24Range.min": "1000000", "marketCapRange.min": "50000000"},
    );

    final overall = body["data"]["overall"];
    final overBought = (overall["overboughtPercentage"] as num?)?.toDouble() ?? 0.0;
    final overSold = (overall["oversoldPercentage"] as num?)?.toDouble() ?? 0.0;
    final avgRsi = overall["averageRsi"].toString();

    final pulse = overBought - overSold;

    repo.updateByType(TickerType.rsi.index, avgRsi);
    repo.updateByType(TickerType.pulse.index, pulse.toString());

    return true;
  }

  Future<bool> fetchEtf() async {
    final body = await _fetchJson(SettingKey.etfEndpoint, query: {"category": "all", "range": "30d"});

    // final total = body["data"]["total"].toString();
    // final btcValue = body["data"]["totalBtcValue"].toString();
    final ethValue = body["data"]["totalEthValue"].toString();

    repo.updateByType(TickerType.etf.index, ethValue);

    return true;
  }

  Future<bool> fetchDominance() async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.marketCapEndpoint) ?? SettingKey.marketCapEndpoint.defaultValue;
    final isLegacy = endpoint.contains("data-api/v4/global-metrics/quotes/historical");

    // New marketcap will populate the dominance!
    if (!isLegacy) {
      logln("Skipping dominance");
      return true;
    }

    final body = await _fetchJson(SettingKey.dominanceEndpoint);

    final dominanceList = body["data"]["dominance"] as List<dynamic>;
    final btc = dominanceList[0]["mcProportion"].toString();

    repo.updateByType(TickerType.dominance.index, btc);

    return true;
  }

  Future<void> refreshRates() async {
    final all = repo.extract();

    final types = all.map((tix) => TickerType.values[tix.type]).toSet();

    if (types.isEmpty) {}

    final jobs = <Future<void>>[];

    if (types.contains(TickerType.altcoinIndex)) {
      jobs.add(fetchAltSeason());
    }
    if (types.contains(TickerType.fearGreed)) {
      jobs.add(fetchFearGreed());
    }
    if (types.contains(TickerType.cmc100)) {
      jobs.add(fetchCmc100());
    }
    if (types.contains(TickerType.marketCap)) {
      jobs.add(fetchMarketCap());
    }
    if (types.contains(TickerType.dominance)) {
      jobs.add(fetchDominance());
    }
    if (types.contains(TickerType.etf)) {
      jobs.add(fetchEtf());
    }
    if (types.contains(TickerType.pulse)) {
      jobs.add(fetchRsi());
    }

    await Future.wait(jobs);

    logln("[TICKERS] Fetching new ticker data completed");
  }

  Map<String, dynamic> parseJson(String body) {
    return json.decode(body) as Map<String, dynamic>;
  }
}
