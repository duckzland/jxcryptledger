import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/abstracts/service.dart';
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

  @override
  Future<void> init() async {
    await repo.init();
    broadcasterListen();
    if (repo.isEmpty()) {
      await refreshRates();
    }
  }

  Future<bool> refreshRates() async {
    final endpoint = settingsRepo.getByKey<String>(SettingKey.marketEndpoint) ?? SettingKey.marketEndpoint.defaultValue;
    final uri = Uri.parse(endpoint).replace(queryParameters: {"start": "1", "limit": "200", "convert": "USD"});
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
        "Markets fetch failed: HTTP [${resp.statusCode}][$uri]",
        "Unable to retrieve data from the server.",
        details: resp.statusCode,
      );
    }

    logln('[MARKETS] Fetching from : $uri [${resp.statusCode}]');

    final markets = await compute(parseMarketsV3, resp.body);

    await repo.replace(markets);

    return true;
  }
}
