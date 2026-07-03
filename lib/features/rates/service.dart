import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../app/exceptions.dart';
import '../../core/abstracts/service.dart';
import '../../core/ipc/action.dart';
import '../../core/log.dart';
import '../../system/settings/keys.dart';
import '../../system/settings/repository.dart';
import 'mixins/helper.dart';
import 'model.dart';
import 'parser.dart';
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
  Timer? _debounce;

  @override
  Future<void> init() async {
    await repo.init();
    await repo.cleanupOldRates();
  }

  @override
  Future<void> dispose() async {
    _debounce?.cancel();
    _watchdog?.cancel();
    _paused?.cancel();
    await super.dispose();
  }

  Future<void> deleteById(int sourceId, int targetId) async {
    logln('[RATES] Deleting $sourceId-$targetId.');
    await repo.delete("$sourceId-$targetId");
  }

  double getStoredRate(int sourceId, int targetId, {bool throwable = false}) {
    // Source and target is the same coin the rate is always 1
    if (sourceId == targetId) {
      return 1;
    }

    if (!throwable) {
      if (!isValidPair(sourceId, targetId)) return -9999;
    } else {
      validateIds(sourceId, targetId);
    }

    final existing = repo.get("$sourceId-$targetId");
    return existing?.rate.toDouble() ?? -9999;
  }

  void addQueue(int sourceId, int targetId, {bool force = false}) {
    if (!isValidPair(sourceId, targetId)) return;

    if (_queue.contains((sourceId, targetId))) return;

    // logln("[RATES] Adding to queue $sourceId - $targetId");

    _queue.add((sourceId, targetId));

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 10), () => _processQueue(force));
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 60), () {
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

    broadcasterEmit(CoreIpcAction.refreshRates, 'start', '', Uint8List(0));

    try {
      final jobs = List<(int, int)>.from(_queue);
      _queue.clear();

      final grouped = _groupJobs(jobs);
      final jobQueue = grouped.entries.map((e) => MapEntry(e.key, e.value.toList())).toList();

      await _runWorkers(jobQueue);
    } finally {
      _watchdog?.cancel();
      _isFetching = false;

      broadcasterEmit(CoreIpcAction.refreshRates, 'complete', '', Uint8List(0));
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
    Future<void> worker() async {
      while (jobQueue.isNotEmpty) {
        MapEntry<int, List<int>>? job;

        try {
          if (jobQueue.isEmpty) return;
          job = jobQueue.removeAt(0);
        } catch (_) {
          return;
        }

        try {
          await _fetchInternal(job.key, job.value);
        } catch (e) {
          logln('[RATES] Unexpected worker error for ${job.key}: $e');

          jobQueue.clear();
          _pauseOperation();
          return;
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (jobQueue.isNotEmpty) {
      const maxWorkers = 5;
      final workersToStart = jobQueue.length == 1 ? 1 : maxWorkers.clamp(1, jobQueue.length);
      await Future.wait(List.generate(workersToStart, (_) => worker()), eagerError: false);
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

    final endpoint = settingsRepo.getByKey<String>(SettingKey.exchangeEndpoint) ?? SettingKey.exchangeEndpoint.defaultValue;
    final authKey = settingsRepo.getByKey<String>(SettingKey.authorizationKey);

    final headers = <String, String>{};
    if (authKey != null && authKey.isNotEmpty) {
      headers['Authorization'] = authKey;
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
      parsed = await compute(parseRatesJson, resp.body);
    } catch (e) {
      throw NetworkingException(
        AppErrorCode.netParseFailure,
        "Rates fetch failed: failed to parse with error",
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
