import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/locator.dart';
import '../../core/log.dart';
import '../settings/repository.dart';
import '../cryptos/repository.dart';

import 'repository.dart';
import 'parser.dart';

class RatesService extends ChangeNotifier {
  final RatesRepository repo;
  final CryptosRepository cryptosRepo;

  bool _isFetching = false;
  bool get isFetching => _isFetching;
  bool get hasRates => repo.hasAny();

  RatesService(this.repo, this.cryptosRepo);

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
        Logln('Failed to fetch rates: sourceId $sourceId not in cryptos_box');
        return false;
      }

      final validTargets = targetIds
          .where((id) => cryptoIds.contains(id))
          .toList();

      if (validTargets.isEmpty) {
        Logln('Failed to fetch rates: no valid targetIds in cryptos_box');
        return false;
      }

      final settings = locator<SettingsRepository>();
      final endpoint =
          settings.get<String>(SettingKey.exchangeEndpoint) ??
          SettingKey.exchangeEndpoint.defaultValue;

      final uri = Uri.parse(endpoint).replace(
        queryParameters: {
          'amount': '1',
          'id': sourceId.toString(),
          'convert_id': _buildConvertIdParam(validTargets),
        },
      );

      final resp = await http.get(uri);

      if (resp.statusCode != 200) {
        Logln('Failed to fetch rates: HTTP ${resp.statusCode}');
        return false;
      }

      final parsed = parseRatesJson(resp.body);

      for (final rate in parsed.rates) {
        if (!cryptoIds.contains(rate.sourceId) ||
            !cryptoIds.contains(rate.targetId)) {
          continue;
        }
        await repo.add(rate);
      }

      Logln("Fetching rates completed: $uri");
      return true;
    } catch (e, st) {
      Logln('Failed to fetch rates: error $e');
      Logln('$st');
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
      final all = await repo.getAll();
      final Map<int, Set<int>> grouped = {};

      for (final r in all) {
        grouped.putIfAbsent(r.sourceId, () => <int>{});
        grouped[r.sourceId]!.add(r.targetId);
      }

      final jobs = <MapEntry<int, List<int>>>[];
      for (final entry in grouped.entries) {
        jobs.add(MapEntry(entry.key, entry.value.toList()));
      }

      const int maxWorkers = 5;
      int activeWorkers = 0;
      int jobIndex = 0;

      final completer = Completer<void>();

      void startWorker() {
        if (jobIndex >= jobs.length) {
          if (activeWorkers == 0 && !completer.isCompleted) {
            completer.complete();
          }
          return;
        }

        final job = jobs[jobIndex++];
        activeWorkers++;

        _fetchInternal(job.key, job.value).whenComplete(() async {
          activeWorkers--;

          await Future.delayed(const Duration(milliseconds: 100));

          startWorker();

          if (activeWorkers == 0 && jobIndex >= jobs.length) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        });
      }

      final initial = jobs.length < maxWorkers ? jobs.length : maxWorkers;
      for (int i = 0; i < initial; i++) {
        startWorker();
      }

      await completer.future;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }
}
