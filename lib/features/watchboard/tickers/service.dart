import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../app/exceptions.dart';
import '../../../core/abstracts/service.dart';
import '../../../core/log.dart';
import '../../../core/mixins/broadcaster.dart';
import '../../../core/mixins/emitter.dart';
import '../../settings/keys.dart';
import '../../settings/repository.dart';
import 'mixins/helper.dart';
import 'model.dart';
import 'repository.dart';

class TickersService extends CoreBaseService<TickersModel, TickersRepository>
    with CoreMixinsEmitter, CoreMixinsBroadcaster, TickersMixinsHelper {
  final SettingsRepository settingsRepo;

  TickersService(super.repo, this.settingsRepo);

  Future<void> populate({bool fetchRate = true}) async {
    for (final tx in defaultTickers) {
      await repo.add(tx);
    }

    if (fetchRate) {
      refreshRates();
    }
  }

  Future<Map<String, dynamic>> _fetchJson(SettingKey key, {Map<String, String>? query}) async {
    final endpoint = settingsRepo.get<String>(key) ?? key.defaultValue;
    final uri = Uri.parse(endpoint).replace(queryParameters: query);
    final authKey = settingsRepo.get<String>(SettingKey.authorizationKey);

    final headers = <String, String>{};
    if (authKey != null && authKey.isNotEmpty) {
      headers['Authorization'] = authKey;
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
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
    final end = DateTime(now.year, now.month + 1, 0).millisecondsSinceEpoch ~/ 1000;

    final body = await _fetchJson(SettingKey.altSeasonEndpoint, query: {"start": start.toString(), "end": end.toString()});

    final nowObj = body["data"]["historicalValues"]["now"];
    final index = nowObj["altcoinIndex"].toString();

    repo.updateByType(TickerType.altcoinIndex.index, index);

    return true;
  }

  Future<bool> fetchFearGreed() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
    final end = DateTime(now.year, now.month + 1, 0).millisecondsSinceEpoch ~/ 1000;

    final body = await _fetchJson(SettingKey.fearGreedEndpoint, query: {"start": start.toString(), "end": end.toString()});

    final nowObj = body["data"]["historicalValues"]["now"];
    final score = nowObj["score"].toString();

    repo.updateByType(TickerType.fearGreed.index, score);

    return true;
  }

  Future<bool> fetchCmc100() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
    final end = DateTime(now.year, now.month + 1, 0).millisecondsSinceEpoch ~/ 1000;

    final body = await _fetchJson(SettingKey.cmc100Endpoint, query: {"start": start.toString(), "end": end.toString()});

    final summary = body["data"]["summaryData"]["currentValue"];
    final value = summary["value"].toString();

    repo.updateByType(TickerType.cmc100.index, value);

    return true;
  }

  Future<bool> fetchMarketCap() async {
    final body = await _fetchJson(SettingKey.marketCapEndpoint, query: {"convertId": "2781", "range": "30d"});

    final nowCap = body["data"]["historicalValues"]["now"]["marketCap"].toString();

    repo.updateByType(TickerType.marketCap.index, nowCap);

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
    final body = await _fetchJson(SettingKey.dominanceEndpoint);

    final dominanceList = body["data"]["dominance"] as List<dynamic>;
    final btc = dominanceList[0]["mcProportion"].toString();

    repo.updateByType(TickerType.dominance.index, btc);

    return true;
  }

  Future<void> refreshRates() async {
    final all = repo.extract();

    final types = all.map((tix) => TickerType.values[tix.type]).toSet();

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
