import '../../core/abstracts/controller.dart';
import '../../core/log.dart';
import '../../core/mixins/controllers/exportable.dart';
import '../../core/mixins/controllers/id_generator.dart';
import '../../core/mixins/controllers/rateable.dart';
import '../../core/utils.dart';
import '../cryptos/service.dart';
import '../notification/service.dart';
import 'model.dart';
import 'repository.dart';

class WatchersController extends CoreBaseController<WatchersModel, WatchersRepository>
    with
        CoreMixinsControllersIdGenerator<WatchersModel, WatchersRepository>,
        CoreMixinsControllersExportable<WatchersModel, WatchersRepository>,
        CoreMixinsControllersRateable<WatchersModel, WatchersRepository> {
  final NotificationService _notificationService;
  final CryptosService _cryptosService;

  WatchersController(super.repo, this._notificationService, this._cryptosService);

  @override
  void init() {
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

  @override
  Future<void> processNewRate(WatchersModel tx, double newRate) async {
    logln("[WATCHERS] Evaluating ${tx.srId}-${tx.rrId}");

    if (tx.isSpent) return;

    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final last = Utils.sanitizeTimestamp(tx.timestamp);
    final nextAllowed = last + (tx.duration * 60000000);
    if (now < nextAllowed) return;

    switch (tx.operatorEnum) {
      case WatchersOperator.equal:
        if (newRate != tx.rates) return;
      case WatchersOperator.lessThan:
        if (newRate >= tx.rates) return;
      case WatchersOperator.greaterThan:
        if (newRate <= tx.rates) return;
    }

    final updated = tx.copyWith(sent: tx.sent + 1, timestamp: now);

    await repo.update(updated);
    load();

    await sendNotification(tx);
  }

  Future<void> sendNotification(WatchersModel tx) async {
    String message = tx.message;
    if (message == "" || message.trim().isEmpty) {
      final sourceSymbol = _cryptosService.getSymbol(tx.srId) ?? "";
      final targetSymbol = _cryptosService.getSymbol(tx.rrId) ?? "";

      message = "$sourceSymbol to $targetSymbol is ${tx.operatorMessage} ${Utils.formatSmartDouble(tx.rates)}.";
    }

    await _notificationService.show(message);
  }

  Future<void> restart() async {
    for (final wx in items) {
      final resetWx = wx.copyWith(sent: 0, timestamp: 0);
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
