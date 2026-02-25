import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jxcryptledger/features/settings/repository.dart';

import '../../core/log.dart';
import 'model.dart';
import 'parser.dart';
import 'repository.dart';

class CryptosService extends ChangeNotifier {
  final CryptosRepository cryptosRepo;
  final SettingsRepository settingsRepo;

  bool _isFetching = false;
  bool get isFetching => _isFetching;

  CryptosService(this.cryptosRepo, this.settingsRepo);

  Future<bool> fetch() async {
    if (_isFetching) return false;

    _isFetching = true;

    try {
      final url = Uri.parse(settingsRepo.get<String>(SettingKey.dataEndpoint) ?? SettingKey.dataEndpoint.defaultValue);

      final resp = await http.get(url);

      if (resp.statusCode != 200) {
        logln("Failed to fetch cryptos: HTTP ${resp.statusCode}");
        return false;
      }

      final parsed = await compute(cryptosParser, {"body": resp.body});

      if (parsed.isEmpty) {
        logln("Failed to fetch cryptos: empty parsed list");
        return false;
      }

      await cryptosRepo.clear();

      for (final m in parsed) {
        await cryptosRepo.add(
          CryptosModel(id: m["id"], name: m["name"], symbol: m["symbol"], status: m["status"], active: m["active"]),
        );
      }

      // Ensure to write to disk!
      await cryptosRepo.flush();

      logln("Fetching cryptos completed");
      notifyListeners();
      return true;
    } catch (e) {
      logln("Failed to fetch cryptos: $e");
      return false;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }
}
