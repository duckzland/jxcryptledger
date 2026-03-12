import 'package:flutter/foundation.dart';
import 'service.dart';

class RatesController extends ChangeNotifier {
  final RatesService service;

  RatesController(this.service) {
    service.registerOnStart(() {
      notifyListeners();
    });
    service.registerOnComplete(() {
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
    await service.refreshRates();
    notifyListeners();
  }

  Future<void> delete(int sourceId, int targetId) async {
    await service.delete(sourceId, targetId);
  }
}
