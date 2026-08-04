import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jxledger/features/rates/parsers/pro_v2.dart';

import '../../app/exceptions.dart';
import '../../core/abstracts/service.dart';
import '../../ipc/action.dart';
import '../../core/log.dart';
import '../../system/settings/keys.dart';
import '../../system/settings/repository.dart';
import 'mixins/helper.dart';
import 'model.dart';
import 'parsers/result.dart';
import 'parsers/v3.dart';
import 'repository.dart';

class RatesService extends CoreBaseService<RatesModel, RatesRepository> with RatesMixinsHelper {
  final SettingsRepository settingsRepo;

  RatesService(super.repo, this.settingsRepo);

  bool _isFetching = false;
  bool get isFetching => _isFetching;
  bool get isPaused => _paused != null;
  bool get hasRates => !repo.isEmpty();

  Timer? _watchdog;
  Timer? _paused;

  final List<(int sourceId, int targetId)> _queue = [];
  List<(int sourceId, int targetId)> _inProcessQueue = [];
  Timer? _debounce;

  late String endpoint;
  late String authKey;
  late bool isCustom;
  late bool isLegacy;
  late bool isFreePlan;
  late bool needAuth;

  @override
  Future<void> init() async {
    await repo.init();
    await repo.cleanupOldRates();
    _detectSettings();
  }

  @override
  Future<void> dispose() async {
    _debounce?.cancel();
    _watchdog?.cancel();
    _paused?.cancel();
    await super.dispose();
  }

  void _detectSettings() {
    endpoint = settingsRepo.getByKey<String>(SettingKey.exchangeEndpoint) ?? SettingKey.exchangeEndpoint.defaultValue;
    authKey = settingsRepo.getByKey<String>(SettingKey.authorizationKey) ?? "";

    isFreePlan = endpoint.contains("https://pro-api.coinmarketcap.com/public-api");
    isCustom = !endpoint.contains("coinmarketcap.com");
    isLegacy = endpoint.contains('v2');
    needAuth = isCustom || endpoint.contains("https://pro-api.coinmarketcap.com/v");
  }

  Future<void> deleteById(int sourceId, int targetId) async {
    // logln('[RATES] Deleting $sourceId-$targetId.');
    await repo.delete("$sourceId-$targetId");
  }

  Decimal getStoredRate(int sourceId, int targetId, {bool throwable = false}) {
    // Source and target is the same coin the rate is always 1
    if (sourceId == targetId) {
      return Decimal.one;
    }

    if (!throwable) {
      if (!isValidPair(sourceId, targetId)) return Decimal.fromInt(-9999);
    } else {
      validateIds(sourceId, targetId);
    }

    final existing = repo.get("$sourceId-$targetId");
    return existing?.rate ?? Decimal.fromInt(-9999);
  }

  void addQueue(int sourceId, int targetId, {bool force = false}) {
    if (!isValidPair(sourceId, targetId)) return;

    if (_queue.contains((sourceId, targetId)) || _inProcessQueue.contains((sourceId, targetId))) return;

    // logln("[RATES] Adding to queue $sourceId - $targetId");

    _queue.add((sourceId, targetId));

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 10), () => _processQueue(force));
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 65), () {
      logln('[RATES] Watchdog triggered — forcing unlock.');
      _isFetching = false;
    });
  }

  void _pauseOperation() {
    logln('[RATES] Pausing operation.');
    _paused?.cancel();
    _paused = Timer(const Duration(seconds: 60), () {
      logln('[RATES] Resuming operation.');
      _paused?.cancel();
      _paused = null;
    });
  }

  Future<void> _processQueue(bool force) async {
    if (isFetching) return;
    if (isPaused) return;
    if (_queue.isEmpty) return;

    _isFetching = force ? false : true;
    _startWatchdog();
    _detectSettings();

    broadcasterEmit(IpcAction.refreshRates, 'start', '', Uint8List(0));

    final maxPayload = isFreePlan ? 1 : (isCustom ? 40 : 1);

    try {
      final jobs = List<(int, int)>.from(_queue);
      _inProcessQueue = List<(int, int)>.from(_queue);
      _queue.clear();

      final grouped = _groupJobs(jobs);
      List<MapEntry<int, List<int>>> jobQueue;

      if (!isLegacy) {
        jobQueue = grouped.entries.map((e) => MapEntry(e.key, e.value.toList())).toList();
      } else {
        jobQueue = grouped.entries.expand((e) {
          final tids = e.value.toList();
          final chunks = <MapEntry<int, List<int>>>[];

          for (var i = 0; i < tids.length; i += maxPayload) {
            final slice = tids.sublist(i, (i + maxPayload > tids.length) ? tids.length : i + maxPayload);
            chunks.add(MapEntry(e.key, slice));
          }

          return chunks;
        }).toList();
      }

      await _runWorkers(jobQueue);
    } finally {
      _inProcessQueue.clear();
      _watchdog?.cancel();
      _isFetching = false;

      logln('[RATES] Process queue completed');

      broadcasterEmit(IpcAction.refreshRates, 'complete', '', Uint8List(0));
    }
  }

  Future<void> refreshRates() async {
    if (cryptosRepo.isEmpty()) {
      logln('[RATES] No cryptos available, skipping refresh.');
      return;
    }

    final all = repo.extract();
    for (final r in all) {
      if (r.sourceId != 0 && r.targetId != 0) {
        addQueue(r.sourceId, r.targetId);
      }
    }

    await _processQueue(false);
  }

  Map<int, Set<int>> _groupJobs(List<(int, int)> jobs) {
    final ids = cryptosRepo.extract().map((c) => c.uuid).toSet();
    final grouped = <int, Set<int>>{};
    final wb = <int, int>{};
    final seen = <(int, int)>{};
    final cleaned = <(int, int)>[];

    for (final j in jobs) {
      final a = j.$1;
      final b = j.$2;

      final reversed = (b, a);

      if (!isValidPair(a, b)) {
        continue;
      }

      if (seen.contains(reversed)) {
        continue;
      }

      seen.add(j);
      cleaned.add(j);
    }

    for (final (sourceId, targetId) in cleaned) {
      wb[sourceId] = (wb[sourceId] ?? 0) + 1;
      wb[targetId] = (wb[targetId] ?? 0) + 1;
    }

    for (final (rawSource, rawTarget) in cleaned) {
      if (!ids.contains(rawSource) || !ids.contains(rawTarget)) {
        continue;
      }

      var sourceId = rawSource;
      var targetId = rawTarget;

      if ((wb[targetId] ?? 0) >= (wb[sourceId] ?? 0)) {
        final tmp = sourceId;
        sourceId = targetId;
        targetId = tmp;
        wb[sourceId] = (wb[sourceId] ?? 0) - 1;
        wb[targetId] = (wb[targetId] ?? 0) + 1;
      }

      grouped.putIfAbsent(sourceId, () => <int>{});
      grouped[sourceId]!.add(targetId);
    }

    for (final sid in grouped.keys.toList()) {
      final uniq = grouped[sid]!.toList();

      if (uniq.length == 1) {
        final nv = uniq.first;
        if (grouped[nv] != null) {
          grouped[nv]!.add(sid);
          grouped.remove(sid);
        }
      }
    }

    return grouped;
  }

  Future<void> _runWorkers(List<MapEntry<int, List<int>>> jobQueue) async {
    if (jobQueue.isEmpty) return;

    final iterator = jobQueue.iterator;
    int hasFailed = 0;

    Future<void> worker(int maxWorkers, int workerIndex) async {
      if (workerIndex > 0) {
        final initialDelay = workerIndex * 200;
        await Future.delayed(Duration(milliseconds: initialDelay));
      }

      workerloop:
      while (hasFailed != 2 && iterator.moveNext()) {
        final job = iterator.current;

        try {
          await _fetchInternal(job.key, job.value);
        } catch (e) {
          if (e is NetworkingException && e.details as int == 429) {
            final code = e.details as int;
            switch (code) {
              case 429:
                logln('[RATES] Rate limited, stopping worker and pausing job: $e');
                hasFailed = 2;
                while (iterator.moveNext()) {}
                break workerloop;
              default:
                break;
            }
          } else {
            hasFailed = 1;
            logln('[RATES] Unexpected worker error for ${job.key}: $e');
          }
        }

        if (hasFailed == 2) break;

        final delayMs = isFreePlan ? (60000 / 30 / maxWorkers).ceil() : 300;
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    int maxWorkers = 5;
    if (isFreePlan) {
      maxWorkers = jobQueue.length < maxWorkers ? jobQueue.length : 1;
    }

    final workersToStart = jobQueue.length == 1 ? 1 : maxWorkers.clamp(1, jobQueue.length);
    await Future.wait(List.generate(workersToStart, (index) => worker(maxWorkers, index)), eagerError: false);

    if (hasFailed == 2) {
      _pauseOperation();
    }
  }

  Future<void> _fetchInternal(int sourceId, List<int> targetIds) async {
    if (cryptosRepo.isEmpty()) {
      throw NetworkingException(
        AppErrorCode.netMissingCryptos,
        "Rates fetch failed: No cryptos map",
        "Unable to retrieve rates from the server.",
      );
    }
    if (sourceId <= 0) {
      throw NetworkingException(
        AppErrorCode.netInvalidRatePayload,
        "Rates fetch failed: Missing sourceId",
        "Unable to retrieve rates from the server.",
      );
    }

    final ids = cryptosRepo.extract().map((c) => c.uuid).toSet();
    final validTargets = targetIds.where(ids.contains).toList();

    if (!ids.contains(sourceId) || validTargets.isEmpty) {
      throw NetworkingException(
        AppErrorCode.netInvalidRatePayload,
        "Rates fetch failed: Invalid id for source and/or target",
        "Unable to retrieve rates from the server.",
      );
    }

    final headers = <String, String>{};
    if (authKey.isNotEmpty && needAuth) {
      if (!isCustom) {
        headers['X-CMC_PRO_API_KEY'] = authKey;
      } else {
        headers['Authorization'] = authKey;
      }
    }

    final uri = Uri.parse(
      endpoint,
    ).replace(queryParameters: {'amount': '1', 'id': sourceId.toString(), 'convert_id': validTargets.join(',')});

    final resp = await http.get(uri, headers: headers);

    // logln('[RATES] Fetching rates : ${sourceId.toString()} ${validTargets.join(',')}');
    logln('[RATES] Fetching from : $uri [${resp.statusCode}]');

    if (resp.statusCode != 200) {
      throw NetworkingException(
        AppErrorCode.netHttpFailure,
        "Rates fetch failed: HTTP ${resp.statusCode}",
        "Unable to retrieve rates from the server.",
        details: resp.statusCode,
      );
    }

    RatesParserResult parsed;

    try {
      parsed = isLegacy ? parseRatesJsonV2(resp.body) : await compute(parseRatesJsonV3, resp.body);
    } catch (e) {
      throw NetworkingException(
        AppErrorCode.netParseFailure,
        "Rates fetch failed: failed to parse with error: $e",
        "The server returned invalid rates data.",
        details: e,
      );
    }

    for (final rate in parsed.rates) {
      if (ids.contains(rate.sourceId) && ids.contains(rate.targetId)) {
        await repo.add(rate);
        // logln('[RATES] Fetched rate for ${rate.sourceId} -> ${rate.targetId} : ${rate.rate}');
      }
    }
  }
}
