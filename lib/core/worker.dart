import 'dart:async';

import '../features/rates/service.dart';
import '../features/transactions/service.dart';
import '../features/watchboard/panels/service.dart';
import '../features/watchboard/tickers/service.dart';
import '../features/watchboard/markets/service.dart';
import '../features/watchers/service.dart';
import '../app/router.dart';
import 'mode.dart';
import 'runtime/locator.dart';
import 'log.dart';

class CoreWorker {
  Timer? _everyMinutesWorker;
  Timer? _everyFiveMinutesWorker;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    final rates = locator<RatesService>();
    final panels = locator<PanelsService>();
    final watchers = locator<WatchersService>();
    final tickers = locator<TickersService>();
    final transactions = locator<TransactionsService>();
    final market = locator<MarketsService>();

    logln("[WORKER] Registering used rates.");
    panels.scheduleRates();
    watchers.scheduleRates();
    transactions.scheduleRates();

    _everyMinutesWorker = Timer.periodic(const Duration(minutes: 1), (_) async {
      bool mustAlwaysFetchRate = false;

      if (!CoreMode.isServer) {
        final current = AppRouter.router.routerDelegate.currentConfiguration.uri.toString();
        if (current == "/tools") {
          mustAlwaysFetchRate = true;
        }
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

    _everyFiveMinutesWorker = Timer.periodic(const Duration(minutes: 5), (_) async {
      logln("[WORKER] Refreshing market rates");
      await market.refreshRates();
    });
  }

  void stop() {
    _everyFiveMinutesWorker?.cancel();
    _everyFiveMinutesWorker = null;

    _everyMinutesWorker?.cancel();
    _everyMinutesWorker = null;

    _started = false;
  }
}
