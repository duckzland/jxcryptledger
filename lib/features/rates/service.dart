import 'dart:async';

import 'package:http/http.dart' as http;

import '../../app/exceptions.dart';
import '../../core/log.dart';
import '../cryptos/repository.dart';
import '../settings/keys.dart';
import '../settings/repository.dart';
import 'model.dart';
import 'parser.dart';
import 'repository.dart';

class RatesService {
  final RatesRepository ratesRepo;
  final CryptosRepository cryptosRepo;
  final SettingsRepository settingsRepo;

  void Function()? onComplete;
  void Function()? onStart;

  RatesService(this.ratesRepo, this.cryptosRepo, this.settingsRepo);

  bool _isFetching = false;
  bool get isFetching => _isFetching;
  bool get hasRates => !ratesRepo.isEmpty();
  Timer? _watchdog;

  final List<(int sourceId, int targetId)> _queue = [];
  Timer? _debounce;

  Future<void> init() async {
    await ratesRepo.cleanupOldRates();
  }

  Future<List<RatesModel>> getAll() async {
    return await ratesRepo.getAll();
  }

  Future<void> delete(int sourceId, int targetId) async {
    logln('[RATES] Deleting $sourceId-$targetId.');
    await ratesRepo.deletePair(sourceId, targetId);
  }

  void registerOnComplete(void Function() cb) {
    logln('[RATES] Registering on complete.');
    onComplete = cb;
  }

  void registerOnStart(void Function() cb) {
    logln('[RATES] Registering on start.');
    onStart = cb;
  }

  Future<double> getStoredRate(int sourceId, int targetId) async {
    _validateIds(sourceId, targetId);
    final existing = await ratesRepo.getPair(sourceId, targetId);
    return existing?.rate.toDouble() ?? -9999;
  }

  void addQueue(int sourceId, int targetId) {
    if (!_isValidPair(sourceId, targetId)) return;

    _queue.add((sourceId, targetId));

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _processQueue);
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 60), () {
      logln('[RATES] Watchdog triggered — forcing unlock.');
      _isFetching = false;
    });
  }

  Future<void> _processQueue() async {
    if (_isFetching) return;
    if (_queue.isEmpty) return;

    _isFetching = true;
    _startWatchdog();

    onStart?.call();
    try {
      final jobs = List<(int, int)>.from(_queue);
      _queue.clear();

      final grouped = _groupJobs(jobs);
      final jobQueue = grouped.entries.map((e) => MapEntry(e.key, e.value.toList())).toList();

      await _runWorkers(jobQueue);
    } finally {
      _watchdog?.cancel();
      _isFetching = false;
      onComplete?.call();
    }
  }

  Future<void> refreshRates() async {
    if (cryptosRepo.isEmpty()) {
      logln('[RATES] No cryptos available, skipping refresh.');
      return;
    }

    final all = await ratesRepo.getAll();
    for (final r in all) {
      if (r.sourceId != 0 && r.targetId != 0) {
        addQueue(r.sourceId, r.targetId);
      }
    }

    await _processQueue();
  }

  bool _isValidPair(int sourceId, int targetId) {
    if (sourceId == 0 || targetId == 0) return false;
    if (cryptosRepo.isEmpty()) return false;

    final ids = cryptosRepo.extract().map((c) => c.uuid).toSet();
    return ids.contains(sourceId) && ids.contains(targetId);
  }

  void _validateIds(int sourceId, int targetId) {
    if (!_isValidPair(sourceId, targetId)) {
      throw NetworkingException(
        AppErrorCode.netInvalidRatePayload,
        'Invalid rate pair: $sourceId -> $targetId',
        "Unable to retrieve rates from the server.",
      );
    }
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

      var source = rawSource;
      var target = rawTarget;

      if ((wb[target] ?? 0) > (wb[source] ?? 0)) {
        final tmp = source;
        source = target;
        target = tmp;
      }

      grouped.putIfAbsent(source, () => <int>{});
      grouped[source]!.add(target);
    }

    for (final sid in grouped.keys.toList()) {
      final uniq = grouped[sid]!.toList();

      if (uniq.length == 1) {
        final nv = uniq.first;

        grouped.putIfAbsent(nv, () => <int>{});
        grouped[nv]!.add(sid);
        grouped.remove(sid);
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

    final endpoint = settingsRepo.get<String>(SettingKey.exchangeEndpoint) ?? SettingKey.exchangeEndpoint.defaultValue;
    final authKey = settingsRepo.get<String>(SettingKey.authorizationKey);

    final headers = <String, String>{};
    if (authKey != null && authKey.isNotEmpty) {
      headers['Authorization'] = authKey;
    }

    final uri = Uri.parse(
      endpoint,
    ).replace(queryParameters: {'amount': '1', 'id': sourceId.toString(), 'convert_id': validTargets.join(',')});

    final resp = await http.get(uri, headers: headers);

    logln('[RATES] Fetching rates : ${sourceId.toString()} ${validTargets.join(',')}');
    // logln('[RATES] Fetching from : $uri [${resp.statusCode}]');

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
      parsed = parseRatesJson(resp.body);
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
        await ratesRepo.add(rate);
      }
    }
  }
}
