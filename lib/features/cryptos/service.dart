import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:jxcryptledger/features/settings/repository.dart';

import '../../core/locator.dart';
import '../../core/log.dart';
import 'model.dart';
import 'repository.dart';
import 'parser.dart';

class CryptosService extends ChangeNotifier {
  final CryptosRepository repo;

  bool _isFetching = false;
  bool get isFetching => _isFetching;

  CryptosService(this.repo);

  Future<bool> fetch() async {
    if (_isFetching) return false;

    _isFetching = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        locator<SettingsRepository>().get<String>(SettingKey.dataEndpoint) ??
            SettingKey.dataEndpoint.defaultValue,
      );

      final resp = await http.get(url);

      if (resp.statusCode != 200) {
        Logln("Failed to fetch cryptos: HTTP ${resp.statusCode}");
        return false;
      }

      final parsed = await compute(cryptosParser, {"body": resp.body});

      if (parsed.isEmpty) {
        Logln("Failed to fetch cryptos: empty parsed list");
        return false;
      }

      await repo.clear();

      for (final m in parsed) {
        await repo.add(
          CryptosModel(
            id: m["id"],
            name: m["name"],
            symbol: m["symbol"],
            status: m["status"],
            active: m["active"],
          ),
        );
      }

      Logln("Fetching cryptos completed");
      return true;
    } catch (e) {
      Logln("Failed to fetch cryptos: $e");
      return false;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }
}
