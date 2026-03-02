import 'package:flutter/foundation.dart';
import '../../core/log.dart';
import 'service.dart';

class RatesController extends ChangeNotifier {
  final RatesService service;

  RatesController(this.service) {
    service.registerOnComplete(() {
      logln("On Rates callback received2");
      notifyListeners();
    });
  }

  bool get isFetching => service.isFetching;
  bool get hasRates => service.hasRates;

  Future<void> init() async {
    await service.init();
    notifyListeners();
  }

  Future<double> getStoredRate(int sourceId, int targetId) {
    return service.getStoredRate(sourceId, targetId);
  }

  void addQueue(int sourceId, int targetId) {
    service.addQueue(sourceId, targetId);
  }

  Future<void> refreshRates() async {
    try {
      final before = service.isFetching;
      await service.refreshRates();
      if (before != service.isFetching) notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
}
