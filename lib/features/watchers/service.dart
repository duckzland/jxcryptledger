import '../../../core/abstracts/service.dart';
import '../../../core/mixins/services/rateable.dart';
import '../../core/log.dart';
import '../../core/utils.dart';
import '../cryptos/service.dart';
import '../notification/service.dart';
import 'model.dart';
import 'repository.dart';

class WatchersService extends CoreBaseService<WatchersModel, WatchersRepository>
    with CoreMixinsServicesRateable<WatchersModel, WatchersRepository> {
  final NotificationService notificationService;
  final CryptosService cryptosService;

  WatchersService(super.repo, this.notificationService, this.cryptosService);

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
      final sourceSymbol = cryptosService.getSymbol(tx.srId) ?? "UNK";
      final targetSymbol = cryptosService.getSymbol(tx.rrId) ?? "UNK";

      message = "$sourceSymbol to $targetSymbol is ${tx.operatorMessage} ${Utils.formatSmartDouble(tx.rates)}.";
    }

    await notificationService.show(message);
  }
}
