import 'dart:async';

import '../core/locator.dart';
import '../core/log.dart';
import '../features/rates/controller.dart';
import '../features/watchers/controller.dart';

class AppWorker {
  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      logln("[Worker] Refreshing transactions rates");
      final rates = locator<RatesController>();
      await rates.refreshRates();

      logln("[Worker] Processing watchers");
      final watchers = locator<WatchersController>();
      await watchers.onRatesUpdated();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}
