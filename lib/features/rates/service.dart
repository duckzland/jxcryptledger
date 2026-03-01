import 'dart:async';
import 'package:http/http.dart' as http;

import '../../app/exceptions.dart';
import '../../core/log.dart';
import '../cryptos/repository.dart';
import '../settings/repository.dart';
import 'parser.dart';
import 'repository.dart';

class RatesService {
  final RatesRepository ratesRepo;
  final CryptosRepository cryptosRepo;
  final SettingsRepository settingsRepo;

  void Function()? onComplete;

  RatesService(this.ratesRepo, this.cryptosRepo, this.settingsRepo);

  bool _isFetching = false;
  bool get isFetching => _isFetching;
  bool get hasRates => ratesRepo.hasAny();

  final List<(int sourceId, int targetId)> _queue = [];
  Timer? _debounce;

  Future<void> init() async {
    await ratesRepo.cleanupOldRates();
  }

  void registerOnComplete(void Function() cb) {
    onComplete = cb;
  }

  Future<double> getStoredRate(int sourceId, int targetId) async {
    try {
      _validateIds(sourceId, targetId);
    } catch (e) {
      rethrow;
    }
    final existing = await ratesRepo.get(sourceId, targetId);
    return existing?.rate.toDouble() ?? -9999;
  }

  void addQueue(int sourceId, int targetId) {
    if (!_isValidPair(sourceId, targetId)) return;

    _queue.add((sourceId, targetId));

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _processQueue);
  }

  Future<void> _processQueue() async {
    if (_isFetching || _queue.isEmpty) return;
    if (!cryptosRepo.hasAny()) return;

    _isFetching = true;

    try {
      final jobs = List<(int, int)>.from(_queue);
      _queue.clear();

      final grouped = _groupJobs(jobs);
      final jobQueue = grouped.entries.map((e) => MapEntry(e.key, e.value.toList())).toList();

      await _runWorkers(jobQueue);

      if (onComplete != null) {
        onComplete!();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refreshRates() async {
    if (!cryptosRepo.hasAny()) {
      logln('RatesService: No cryptos available, skipping refresh.');
      return;
    }

    final all = await ratesRepo.getAll();
    for (final r in all) {
      if (r.sourceId != 0 && r.targetId != 0) {
        addQueue(r.sourceId, r.targetId);
      }
    }

    try {
      await _processQueue();
    } catch (e) {
      rethrow;
    }
  }

  bool _isValidPair(int sourceId, int targetId) {
    if (sourceId == 0 || targetId == 0) return false;
    if (!cryptosRepo.hasAny()) return false;

    final ids = cryptosRepo.getAll().map((c) => c.id).toSet();
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
    final ids = cryptosRepo.getAll().map((c) => c.id).toSet();
    final grouped = <int, Set<int>>{};

    for (final (sourceId, targetId) in jobs) {
      if (!ids.contains(sourceId) || !ids.contains(targetId)) continue;

      grouped.putIfAbsent(sourceId, () => <int>{});
      grouped[sourceId]!.add(targetId);
    }

    return grouped;
  }

  Future<void> _runWorkers(List<MapEntry<int, List<int>>> jobQueue) async {
    Future<void> worker() async {
      while (jobQueue.isNotEmpty) {
        final job = jobQueue.removeAt(0);
        try {
          await _fetchInternal(job.key, job.value);
        } catch (e) {
          rethrow;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    const maxWorkers = 5;
    final workersToStart = maxWorkers.clamp(1, jobQueue.length);
    await Future.wait(List.generate(workersToStart, (_) => worker()));
  }

  Future<bool> _fetchInternal(int sourceId, List<int> targetIds) async {
    if (!cryptosRepo.hasAny()) return false;
    if (sourceId <= 0) return false;

    try {
      final ids = cryptosRepo.getAll().map((c) => c.id).toSet();
      final validTargets = targetIds.where(ids.contains).toList();

      if (!ids.contains(sourceId) || validTargets.isEmpty) return false;

      final endpoint = settingsRepo.get<String>(SettingKey.exchangeEndpoint) ?? SettingKey.exchangeEndpoint.defaultValue;

      final uri = Uri.parse(
        endpoint,
      ).replace(queryParameters: {'amount': '1', 'id': sourceId.toString(), 'convert_id': validTargets.join(',')});

      final resp = await http.get(uri);
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

      return true;
    } catch (_) {
      return false;
    }
  }
}
