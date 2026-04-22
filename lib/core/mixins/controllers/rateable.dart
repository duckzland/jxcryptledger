import '../../../features/rates/service.dart';
import '../../abstracts/controller.dart';
import '../../abstracts/models/with_id.dart';
import '../../abstracts/models/rateable.dart';
import '../../abstracts/repository.dart';
import '../../locator.dart';

mixin CoreMixinsControllersRateable<T extends CoreModelWithId, R extends CoreBaseRepository<T>> on CoreBaseController<T, R> {
  final RatesService rateableService = locator<RatesService>();

  @override
  Future<void> add(T tx) async {
    final rx = tx as CoreModelRateable;
    rateableService.addQueue(rx.srId, rx.rrId);
    await repo.add(tx);
    load();
  }

  @override
  Future<void> update(T tx) async {
    final rx = tx as CoreModelRateable;
    rateableService.addQueue(rx.srId, rx.rrId);
    await repo.update(tx);
    load();
  }

  void scheduleRates() {
    load();
    for (final tx in items) {
      final rx = tx as CoreModelRateable;
      rateableService.addQueue(rx.srId, rx.rrId);
    }
  }

  Future<void> onRatesUpdated() async {
    for (final tx in items) {
      final rx = tx as CoreModelRateable;
      final current = rateableService.getStoredRate(rx.srId, rx.rrId);
      if (current == -9999) {
        rateableService.addQueue(rx.srId, rx.rrId);
        continue;
      }

      processNewRate(tx, current);
    }
  }

  Future<void> processNewRate(T tx, double newRate) async {}

  Future<void> refreshRates() async {
    await rateableService.refreshRates();
    load();
  }

  List<String> getAllRateID() {
    final ids = <String>[];

    for (final tx in items) {
      final rx = tx as CoreModelRateable;
      if (rx.isRateable) {
        ids.add("${rx.srId}-${rx.rrId}");
        ids.add("${rx.rrId}-${rx.srId}");
      }
    }

    return ids;
  }
}
