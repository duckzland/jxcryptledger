import 'package:flutter/foundation.dart';
import 'service.dart';

class RatesController extends ChangeNotifier {
  final RatesService service;

  RatesController(this.service);

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
    service.registerOnComplete(() => notifyListeners());
  }

  Future<void> refreshRates() async {
    final before = service.isFetching;
    await service.refreshRates();
    if (before != service.isFetching) notifyListeners();
  }
}
