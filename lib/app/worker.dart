import 'dart:async';

import '../core/locator.dart';
import '../core/log.dart';
import '../features/rates/controller.dart';
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
      logln("[WORKER] Refreshing transactions rates");
      final rates = locator<RatesController>();
      await rates.refreshRates();

      logln("[WORKER] Processing watchers");
      final watchers = locator<WatchersController>();
      await watchers.onRatesUpdated();

      logln("[WORKER] Processing panels");
      final panels = locator<PanelsController>();
      await panels.onRatesUpdated();

      logln("[WORKER] Refreshing tickers rates");
      final tickers = locator<TickersController>();
      await tickers.refreshRates();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
