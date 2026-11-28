import 'package:decimal/decimal.dart';

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
  Future<WatchersModel?> processNewRate(WatchersModel tx, Decimal newRate) async {
    logln("Evaluating ${tx.srId}-${tx.rrId}", "WATCHERS");
    if (tx.isSpent) return null;

    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final last = Utils.sanitizeTimestamp(tx.timestamp);
    final nextAllowed = last + (tx.duration * 60000000);
    if (now < nextAllowed) return null;

    switch (tx.operatorEnum) {
      case WatchersOperator.equal:
        if (newRate != tx.rates) return null;
      case WatchersOperator.lessThan:
        if (newRate >= tx.rates) return null;
      case WatchersOperator.greaterThan:
        if (newRate <= tx.rates) return null;
    }

    final updated = tx.copyWith(sent: tx.sent + 1, timestamp: now);

    // await repo.update(updated);
    // load();

    await sendNotification(tx);

    return updated;
  }

  Future<void> sendNotification(WatchersModel tx) async {
    String message = tx.message;
    if (message == "" || message.trim().isEmpty) {
      final sourceSymbol = cryptosService.getSymbol(tx.srId) ?? "UNK";
      final targetSymbol = cryptosService.getSymbol(tx.rrId) ?? "UNK";

      message = "$sourceSymbol to $targetSymbol is ${tx.operatorMessage} ${Utils.formatSmartDecimal(tx.rates)}.";
    }

    await notificationService.show(message);
  }
}
