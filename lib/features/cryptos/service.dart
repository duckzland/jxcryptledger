import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../app/exceptions.dart';
import '../settings/repository.dart';
import '../../core/log.dart';
import 'model.dart';
import 'parser.dart';
import 'repository.dart';

class CryptosService {
  final CryptosRepository cryptosRepo;
  final SettingsRepository settingsRepo;

  bool _isFetching = false;
  bool get isFetching => _isFetching;

  CryptosService(this.cryptosRepo, this.settingsRepo);

  Future<bool> fetch() async {
    if (_isFetching) return false;

    _isFetching = true;

    try {
      final endpoint = settingsRepo.get<String>(SettingKey.dataEndpoint) ?? SettingKey.dataEndpoint.defaultValue;

      final url = Uri.parse(endpoint);
      final resp = await http.get(url);

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

      await cryptosRepo.clear();

      for (final m in parsed) {
        await cryptosRepo.add(CryptosModel(id: m["id"], name: m["name"], symbol: m["symbol"], status: m["status"], active: m["active"]));
      }

      await cryptosRepo.flush();
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
