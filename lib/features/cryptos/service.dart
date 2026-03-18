import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../app/exceptions.dart';
import '../settings/repository.dart';
import '../settings/keys.dart';
import '../../core/log.dart';
import 'model.dart';
import 'parser.dart';
import 'repository.dart';

class CryptosService {
  final CryptosRepository repo;
  final SettingsRepository settingsRepo;

  bool _isFetching = false;
  bool get isFetching => _isFetching;

  CryptosService(this.repo, this.settingsRepo);

  String? getSymbol(int id) {
    return repo.getSymbol(id);
  }

  Future<List<CryptosModel>> getAll() {
    return repo.getAll();
  }

  CryptosModel? getById(int id) {
    return repo.getById(id);
  }

  Future<bool> fetch() async {
    if (_isFetching) return false;

    _isFetching = true;

    try {
      final endpoint = settingsRepo.get<String>(SettingKey.dataEndpoint) ?? SettingKey.dataEndpoint.defaultValue;
      final authKey = settingsRepo.get<String>(SettingKey.authorizationKey);

      final headers = <String, String>{};
      if (authKey != null && authKey.isNotEmpty) {
        headers['Authorization'] = authKey;
      }

      final url = Uri.parse(endpoint);
      final resp = await http.get(url, headers: headers);

      if (resp.statusCode != 200) {
        throw NetworkingException(
          AppErrorCode.netHttpFailure,
          "Cryptos fetch failed: HTTP ${resp.statusCode}",
          "Unable to retrieve crypto data from the server.",
          details: resp.statusCode,
        );
      }

      final parsed = await compute(cryptosParser, {"body": resp.body});

      if (parsed.isEmpty) {
        throw NetworkingException(
          AppErrorCode.netEmptyResponse,
          "Cryptos fetch failed: parsed list is empty",
          "The server returned invalid crypto data.",
        );
      }

      await repo.clear();

      for (final m in parsed) {
        await repo.add(CryptosModel(id: m["id"], name: m["name"], symbol: m["symbol"], status: m["status"], active: m["active"]));
      }

      await repo.flush();
      logln("Fetching cryptos completed");
      return true;
    } on NetworkingException {
      rethrow;
    } catch (e, st) {
      throw NetworkingException(
        AppErrorCode.netUnknownFailure,
        "Cryptos fetch failed with unexpected error: $e",
        "An unexpected error occurred while fetching crypto data.",
        details: st,
      );
    } finally {
      _isFetching = false;
    }
  }
}
