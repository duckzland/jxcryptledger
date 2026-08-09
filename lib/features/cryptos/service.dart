import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../app/exceptions.dart';
import '../../core/abstracts/service.dart';
import '../../core/worker/job.dart';
import '../../core/worker/processor.dart';
import '../../ipc/action.dart';
import '../../system/settings/repository.dart';
import '../../system/settings/keys.dart';
import '../../core/log.dart';
import 'model.dart';
import 'parsers/legacy.dart';
import 'parsers/pro_v1.dart';
import 'repository.dart';

class CryptosService extends CoreBaseService<CryptosModel, CryptosRepository> {
  final SettingsRepository settingsRepo;
  final CoreWorkerProcessor worker = CoreWorkerProcessor(maxWorkers: 1, watchdogTimeout: Duration(minutes: 3));

  bool get isFetching => worker.isFetching;

  CryptosService(super.repo, this.settingsRepo);

  String? getSymbol(int id) {
    return repo.getSymbol(id);
  }

  List<CryptosModel> getAll() {
    return repo.extract();
  }

  CryptosModel? getById(int id) {
    return repo.get(id.toString());
  }

  int? getIdBySymbol(String symbol) {
    return repo.getIdBySymbol(symbol);
  }

  Future<bool> fetch() async {
    if (worker.isFetching) return false;

    broadcasterEmit(IpcAction.refreshCryptos, 'start', '', Uint8List(0));

    try {
      final cryptoJob = CoreWorkerJob(
        id: SettingKey.dataEndpoint.index,
        payload: const <int>[],
        isFreePlan: true,
        callback: _fetchInternal,
      );

      await worker.run([cryptoJob]);
      return true;
    } catch (e) {
      logln('[CRYPTOS] Unexpected Error: $e');
      return false;
    } finally {
      logln('[CRYPTOS] Fetch cryptos completed');
      broadcasterEmit(IpcAction.refreshCryptos, 'complete', '', Uint8List(0));
    }
  }

  Future<void> _fetchInternal(int id, List<int> payload, {http.Client? fetcher}) async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.dataEndpoint) ?? SettingKey.dataEndpoint.defaultValue;
    final authKey = settingsRepo.getByKey<String>(SettingKey.authorizationKey);

    final isLegacy = endpoint.contains("generated/core/crypto/cryptos.json");
    final isCustom = !endpoint.contains("coinmarketcap.com");

    bool needAuth = isCustom || endpoint == "https://pro-api.coinmarketcap.com/v1/cryptocurrency/map";
    Map<String, dynamic> query = isLegacy ? {} : {'listing_status': 'active', 'aux': 'is_active,status'};

    final headers = <String, String>{};
    if (authKey != null && authKey.isNotEmpty && needAuth) {
      if (!isCustom) {
        headers['X-CMC_PRO_API_KEY'] = authKey;
      } else {
        headers['Authorization'] = authKey;
      }
    }

    final uri = Uri.parse(endpoint).replace(queryParameters: query);

    final client = fetcher ?? http.Client();
    final http.Response resp;

    try {
      resp = await client.get(uri, headers: headers);
    } finally {
      if (fetcher == null) {
        client.close();
      }
    }

    logln('[CRYPTOS] Fetching from : $uri [${resp.statusCode}]');

    if (resp.statusCode != 200) {
      throw NetworkingException(
        AppErrorCode.netHttpFailure,
        "Cryptos fetch failed: HTTP ${resp.statusCode}",
        "Unable to retrieve crypto data from the server.",
        details: resp.statusCode,
      );
    }

    final parsed = await compute(isLegacy ? cryptosParsersLegacy : cryptosParsersProV1, {"body": resp.body});
    if (parsed.isEmpty) {
      throw NetworkingException(
        AppErrorCode.netEmptyResponse,
        "Cryptos fetch failed: parsed list is empty",
        "The server returned invalid crypto data.",
      );
    }

    final List<CryptosModel> models = parsed
        .map((m) => CryptosModel(id: m["id"], name: m["name"], symbol: m["symbol"], status: m["status"], active: m["active"]))
        .toList();

    await repo.replace(models);
    await repo.flush();
  }
}
