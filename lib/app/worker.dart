import 'dart:async';

import '../app/router.dart';
import '../core/locator.dart';
import '../core/log.dart';
import '../features/rates/service.dart';
import '../features/transactions/service.dart';
import '../features/watchboard/panels/service.dart';
import '../features/watchboard/tickers/service.dart';
import '../features/watchers/service.dart';

class AppWorker {
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    final rates = locator<RatesService>();
    final panels = locator<PanelsService>();
    final watchers = locator<WatchersService>();
    final tickers = locator<TickersService>();
    final transactions = locator<TransactionsService>();

    logln("[WORKER] Registering used rates.");
    panels.scheduleRates();
    watchers.scheduleRates();
    transactions.scheduleRates();

    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      bool mustAlwaysFetchRate = false;
      final current = AppRouter.router.routerDelegate.currentConfiguration.uri.toString();
      if (current == "/tools") {
        mustAlwaysFetchRate = true;
      }

      final pxs = panels.getAllRateID();
      final wxs = watchers.getAllRateID();
      final txs = transactions.getAllRateID();
      final uxs = [...pxs, ...wxs, ...txs];

      if (uxs.isNotEmpty) {
        logln("[WORKER] Trying to clean old rates");
        final rxs = rates.extract();
        for (final rx in rxs) {
          final key = '${rx.sourceId}-${rx.targetId}';
          if (!uxs.contains(key)) {
            await rates.deleteById(rx.sourceId, rx.targetId);
          }
        }
      }

      if (!panels.isEmpty() || !watchers.isEmpty() || !transactions.isEmpty() || mustAlwaysFetchRate) {
        logln("[WORKER] Refreshing transactions rates");
        await rates.refreshRates();
      }

      if (!watchers.isEmpty()) {
        logln("[WORKER] Processing watchers");
        await watchers.onRatesUpdated();
      }

      if (!panels.isEmpty()) {
        logln("[WORKER] Processing panels");
        await panels.onRatesUpdated();
      }

      if (!panels.isEmpty()) {
        logln("[WORKER] Refreshing tickers rates");
        await tickers.refreshRates();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
