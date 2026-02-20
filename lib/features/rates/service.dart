import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/log.dart';
import '../cryptos/repository.dart';
import '../settings/repository.dart';
import 'parser.dart';
import 'repository.dart';

class RatesService extends ChangeNotifier {
  final RatesRepository ratesRepo;
  final CryptosRepository cryptosRepo;
  final SettingsRepository settingsRepo;

  bool _isFetching = false;
  bool get isFetching => _isFetching;
  bool get hasRates => ratesRepo.hasAny();

  RatesService(this.ratesRepo, this.cryptosRepo, this.settingsRepo);

  String _buildConvertIdParam(List<int> targetIds) {
    final seen = <int>{};
    final result = <int>[];

    for (final id in targetIds) {
      if (!seen.contains(id)) {
        seen.add(id);
        result.add(id);
      }
    }

    return result.join(',');
  }

  Future<bool> _fetchInternal(int sourceId, List<int> targetIds) async {
    try {
      // Validate IDs exist in cryptos_box
      final allCryptos = await cryptosRepo.getAll();
      final cryptoIds = allCryptos.map((c) => c.id).toSet();

      if (!cryptoIds.contains(sourceId)) {
        logln('Failed to fetch rates: sourceId $sourceId not in cryptos_box');
        return false;
      }

      final validTargets = targetIds.where((id) => cryptoIds.contains(id)).toList();

      if (validTargets.isEmpty) {
        logln('Failed to fetch rates: no valid targetIds in cryptos_box');
        return false;
      }

      final endpoint =
          settingsRepo.get<String>(SettingKey.exchangeEndpoint) ?? SettingKey.exchangeEndpoint.defaultValue;

      final uri = Uri.parse(endpoint).replace(
        queryParameters: {'amount': '1', 'id': sourceId.toString(), 'convert_id': _buildConvertIdParam(validTargets)},
      );

      final resp = await http.get(uri);

      if (resp.statusCode != 200) {
        logln('Failed to fetch rates: HTTP ${resp.statusCode}');
        return false;
      }

      final parsed = parseRatesJson(resp.body);

      for (final rate in parsed.rates) {
        if (!cryptoIds.contains(rate.sourceId) || !cryptoIds.contains(rate.targetId)) {
          continue;
        }
        await ratesRepo.add(rate);
      }

      logln("Fetching rates completed: $uri");
      return true;
    } catch (e, st) {
      logln('Failed to fetch rates: error $e');
      logln('$st');
      return false;
    }
  }

  Future<bool> fetch(int sourceId, List<int> targetIds) async {
    if (_isFetching) return false;

    _isFetching = true;
    notifyListeners();

    try {
      return await _fetchInternal(sourceId, targetIds);
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  Future<void> refreshRates() async {
    if (_isFetching) return;

    _isFetching = true;
    notifyListeners();

    try {
      final all = await ratesRepo.getAll();
      final Map<int, Set<int>> grouped = {};

      for (final r in all) {
        grouped.putIfAbsent(r.sourceId, () => <int>{});
        grouped[r.sourceId]!.add(r.targetId);
      }

      final List<MapEntry<int, List<int>>> jobQueue = grouped.entries
          .map((e) => MapEntry(e.key, e.value.toList()))
          .toList();

      Future<void> worker() async {
        while (true) {
          MapEntry<int, List<int>>? job;

          if (jobQueue.isNotEmpty) {
            job = jobQueue.removeAt(0);
          } else {
            break;
          }

          await _fetchInternal(job.key, job.value);
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      final int maxWorkers = 5;
      final int workersToStart = maxWorkers.clamp(1, jobQueue.length);
      final workers = List<Future<void>>.generate(workersToStart, (_) => worker(), growable: false);

      await Future.wait(workers);
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }
}
