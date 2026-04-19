import '../../core/abstracts/controller.dart';
import '../../core/log.dart';
import '../../core/mixins/controllers/exportable.dart';
import '../../core/mixins/controllers/id_generator.dart';
import '../../core/mixins/controllers/rateable.dart';
import '../../core/utils.dart';
import '../cryptos/service.dart';
import '../notification/service.dart';
import '../rates/service.dart';
import 'model.dart';
import 'repository.dart';

class WatchersController extends CoreBaseController<WatchersModel, WatchersRepository>
    with
        CoreMixinsControllersIdGenerator<WatchersModel, WatchersRepository>,
        CoreMixinsControllersExportable<WatchersModel, WatchersRepository>,
        CoreMixinsControllersRateable<WatchersModel, WatchersRepository> {
  final RatesService _ratesService;
  final NotificationService _notificationService;
  final CryptosService _cryptosService;

  WatchersController(super.repo, this._ratesService, this._notificationService, this._cryptosService);

  @override
  void init() {
    load();
    for (final wx in items) {
      _ratesService.addQueue(wx.srId, wx.rrId);
    }
  }

  @override
  Future<void> add(WatchersModel tx) async {
    _ratesService.addQueue(tx.srId, tx.rrId);
    await repo.add(tx);
    load();
  }

  @override
  Future<void> update(WatchersModel tx) async {
    _ratesService.addQueue(tx.srId, tx.rrId);
    await repo.update(tx);
    load();
  }

  @override
  Future<void> remove(WatchersModel tx) async {
    await _ratesService.delete(tx.srId, tx.rrId);
    await _ratesService.delete(tx.rrId, tx.srId);
    await repo.remove(tx);
    load();
  }

  @override
  Future<void> clear() async {
    for (final tx in items) {
      await _ratesService.delete(tx.srId, tx.rrId);
      await _ratesService.delete(tx.rrId, tx.srId);
    }
    await repo.clear();
    load();
  }

  WatchersModel? getLinked(String linkKey) {
    for (final wx in items) {
      if (wx.meta['txLink'] == linkKey) {
        return wx;
      }
    }

    return null;
  }

  Future<void> onRatesUpdated() async {
    for (final w in items) {
      logln("[WATCHER] Evaluating ${w.srId}-${w.rrId}");
      process(w);
    }
  }

  Future<void> process(WatchersModel tx) async {
    if (tx.isSpent()) return;

    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final last = Utils.sanitizeTimestamp(tx.timestamp);
    final nextAllowed = last + (tx.duration * 60000000);
    if (now < nextAllowed) return;

    final current = _ratesService.getStoredRate(tx.srId, tx.rrId);
    if (current == -9999) {
      _ratesService.addQueue(tx.srId, tx.rrId);
      return;
    }

    switch (tx.operatorEnum) {
      case WatchersOperator.equal:
        if (current != tx.rates) return;
      case WatchersOperator.lessThan:
        if (current >= tx.rates) return;
      case WatchersOperator.greaterThan:
        if (current <= tx.rates) return;
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
