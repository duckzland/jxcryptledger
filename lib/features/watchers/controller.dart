import '../../core/abstracts/controller.dart';
import '../../core/ipc/action.dart';
import '../../core/mixins/controllers/exportable.dart';
import '../../core/mixins/controllers/id_generator.dart';
import '../../core/mixins/controllers/rateable.dart';
import '../../core/utils.dart';
import '../cryptos/controller.dart';
import 'model.dart';
import 'repository.dart';

class WatchersController extends CoreBaseController<WatchersModel, WatchersRepository>
    with
        CoreMixinsControllersIdGenerator<WatchersModel, WatchersRepository>,
        CoreMixinsControllersExportable<WatchersModel, WatchersRepository>,
        CoreMixinsControllersRateable<WatchersModel, WatchersRepository> {
  final CryptosController _cryptosController;

  WatchersController(super.repo, this._cryptosController);

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
      final sourceSymbol = _cryptosController.getSymbol(tx.srId) ?? "UNK";
      final targetSymbol = _cryptosController.getSymbol(tx.rrId) ?? "UNK";

      message = "$sourceSymbol to $targetSymbol is ${tx.operatorMessage} ${Utils.formatSmartDouble(tx.rates)}.";
    }

    await ipcClient.send(op: CoreIpcAction.notification, action: 'action', key: "notification", payload: message);
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
