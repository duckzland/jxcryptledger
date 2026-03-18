import 'dart:async';

import '../core/locator.dart';
import '../core/log.dart';
import '../features/rates/controller.dart';
import '../features/transactions/controller.dart';
import '../features/watchboard/panels/controller.dart';
import '../features/watchboard/tickers/controller.dart';
import '../features/watchers/controller.dart';

class AppWorker {
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final rates = locator<RatesController>();
      final panels = locator<PanelsController>();
      final watchers = locator<WatchersController>();
      final tickers = locator<TickersController>();
      final transactions = locator<TransactionsController>();

      // Wipe non used rates early
      final pxs = panels.getAllRateID();
      final wxs = watchers.getAllRateID();
      final txs = transactions.getAllRateID();
      final uxs = [...pxs, ...wxs, ...txs];

      if (uxs.isNotEmpty) {
        final rxs = await rates.getAll();
        for (final rx in rxs) {
          final key = '${rx.sourceId}-${rx.targetId}';
          if (!uxs.contains(key)) {
            logln("[WORKER] Wiping old rates for $key");
            await rates.delete(rx.sourceId, rx.targetId);
          }
        }
      }

      if (!panels.isEmpty() || !watchers.isEmpty() || !transactions.isEmpty()) {
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
