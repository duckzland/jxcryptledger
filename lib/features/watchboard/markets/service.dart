import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/abstracts/service.dart';
import '../../../core/worker/job.dart';
import '../../../core/worker/processor.dart';
import '../../../ipc/action.dart';
import '../../../system/settings/keys.dart';
import '../../../system/settings/repository.dart';
import '../../../app/exceptions.dart';
import '../../../core/log.dart';
import 'model.dart';
import 'parsers/pro_v3.dart';
import 'repository.dart';

class MarketsService extends CoreBaseService<MarketsModel, MarketsRepository> {
  final SettingsRepository settingsRepo;

  MarketsService(super.repo, this.settingsRepo);

  final CoreWorkerProcessor worker = CoreWorkerProcessor(maxWorkers: 1);

  @override
  Future<void> init() async {
    await super.init();

    if (repo.isEmpty()) {
      await refreshRates();
    }
  }

  Future<bool> refreshRates() async {
    if (worker.isFetching) return true;

    broadcasterEmit(IpcAction.refreshMarket, 'start', '', Uint8List(0));

    try {
      final marketJob = CoreWorkerJob(
        id: SettingKey.marketEndpoint.index,
        payload: const <int>[],
        isFreePlan: true,
        callback: _fetchInternal,
      );

      await worker.run([marketJob]);
      return true;
    } catch (e) {
      logln("Unexpected Error: $e", "MARKETS");
      return false;
    } finally {
      logln("Refresh rates completed", "MARKETS");
      broadcasterEmit(IpcAction.refreshMarket, 'complete', '', Uint8List(0));
    }
  }

  Future<void> _fetchInternal(int id, List<int> payload, {http.Client? fetcher}) async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.marketEndpoint) ?? SettingKey.marketEndpoint.defaultValue;
    final uri = Uri.parse(endpoint).replace(queryParameters: {"start": "1", "limit": "200", "convert": "USD"});
    final authKey = settingsRepo.getByKey<String>(SettingKey.authorizationKey);

    final isCustom = !endpoint.contains("coinmarketcap.com");
    final needAuth = isCustom || endpoint.contains("https://coinmarketcap.com");

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

    logln("Fetching from : $uri [${resp.statusCode}]", "MARKETS");

    if (resp.statusCode != 200) {
      throw NetworkingException(
        AppErrorCode.netHttpFailure,
        "Markets fetch failed: HTTP [${resp.statusCode}][$uri]",
        "Unable to retrieve data from the server.",
        details: resp.statusCode,
      );
    }

    logln("Fetching from : $uri [${resp.statusCode}]", "MARKETS");

    final markets = await compute(parseMarketsV3, resp.body);
    await repo.replace(markets);
  }
}
