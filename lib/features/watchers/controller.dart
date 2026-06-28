import 'dart:convert';

import '../../core/abstracts/controller.dart';
import '../../core/mixins/broadcaster.dart';
import '../../core/mixins/controllers/exportable.dart';
import '../../core/mixins/controllers/id_generator.dart';
import '../../core/mixins/controllers/rateable.dart';
import '../../core/utils.dart';
import '../cryptos/service.dart';
import 'model.dart';
import 'repository.dart';

class WatchersController extends CoreBaseController<WatchersModel, WatchersRepository>
    with
        CoreMixinsBroadcaster,
        CoreMixinsControllersIdGenerator<WatchersModel, WatchersRepository>,
        CoreMixinsControllersExportable<WatchersModel, WatchersRepository>,
        CoreMixinsControllersRateable<WatchersModel, WatchersRepository> {
  final CryptosService _cryptosService;

  WatchersController(super.repo, this._cryptosService);

  @override
  Future<void> init() async {
    await super.init();
    scheduleRates();
  }

  WatchersModel? getLinked(String linkKey) {
    for (final wx in items) {
      if (wx.meta['txLink'] == linkKey) {
        return wx;
      }
    }

    return null;
  }

  Future<void> sendNotification(WatchersModel tx) async {
    String message = tx.message;
    if (message == "" || message.trim().isEmpty) {
      final sourceSymbol = _cryptosService.getSymbol(tx.srId) ?? "UNK";
      final targetSymbol = _cryptosService.getSymbol(tx.rrId) ?? "UNK";

      message = "$sourceSymbol to $targetSymbol is ${tx.operatorMessage} ${Utils.formatSmartDouble(tx.rates)}.";
    }

    await ipcClient.send(op: 0x12, box: 'action', key: "notification", value: utf8.encode(message));
  }

  Future<void> restart() async {
    for (final wx in items) {
      final resetWx = wx.copyWith(sent: 0, timestamp: 1);
      await repo.update(resetWx);
    }

    load();
  }

  bool hasRestartable() {
    for (final wx in items) {
      if (wx.sent >= wx.limit) {
        return true;
      }
    }
    return false;
  }
}
