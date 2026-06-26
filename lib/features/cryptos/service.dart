import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../app/exceptions.dart';
import '../../app/runtime.dart';
import '../../core/abstracts/service.dart';
import '../../core/ipc/event.dart';
import '../../core/mixins/broadcaster.dart';
import '../../core/mixins/emitter.dart';
import '../settings/repository.dart';
import '../settings/keys.dart';
import '../../core/log.dart';
import 'model.dart';
import 'parser.dart';
import 'repository.dart';

class CryptosService extends CoreBaseService<CryptosModel, CryptosRepository> with CoreMixinsEmitter, CoreMixinsBroadcaster {
  final SettingsRepository settingsRepo;

  bool _isFetching = false;
  bool get isFetching => _isFetching;

  CryptosService(super.repo, this.settingsRepo) {
    broadcasterListen();
  }

  @override
  void broadcasterAction(CoreIpcBroadcastEvent event) {
    if (event.op == 0x11) {
      if (event.boxName == "start") {
        _isFetching = true;
        emitterEmit("cryptos_refresh_start");
      }

      if (event.boxName == "complete") {
        _isFetching = false;
        emitterEmit("cryptos_refresh_complete");
      }
    }
  }

  String? getSymbol(int id) {
    return repo.getSymbol(id);
  }

  List<CryptosModel> getAll() {
    return repo.extract();
  }

  CryptosModel? getById(int id) {
    return repo.get(id.toString());
  }

  Future<bool> fetch() async {
    if (!AppRuntime.instance.isServer()) {
      await broadcasterSend(op: 0x11, box: "action");
      return true;
    }

    if (_isFetching) return false;

    _isFetching = true;

    broadcasterEmit(0x11, 'start', '', Uint8List(0));

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
        final model = CryptosModel(id: m["id"], name: m["name"], symbol: m["symbol"], status: m["status"], active: m["active"]);
        await repo.add(model);
      }

      await repo.flush();

      logln("Fetching cryptos completed");
      return true;
    } on NetworkingException {
      rethrow;
    } catch (e) {
      throw NetworkingException(
        AppErrorCode.netUnknownFailure,
        "Cryptos fetch failed with unexpected error: $e",
        "An unexpected error occurred while fetching crypto data.",
      );
    } finally {
      _isFetching = false;
      broadcasterEmit(0x11, 'complete', '', Uint8List(0));
    }
  }
}
