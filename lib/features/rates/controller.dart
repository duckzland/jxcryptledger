import 'package:flutter/foundation.dart';
import 'model.dart';
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

  List<RatesModel> getAll() {
    return service.getAll();
  }

  double getStoredRate(int sourceId, int targetId, {bool throwable = false}) {
    return service.getStoredRate(sourceId, targetId, throwable: throwable);
  }

  void addQueue(int sourceId, int targetId, {bool force = true}) {
    service.addQueue(sourceId, targetId, force: force);
  }

  Future<void> refreshRates() async {
    await service.refreshRates();
    notifyListeners();
  }

  Future<void> delete(int sourceId, int targetId) async {
    await service.delete(sourceId, targetId);
  }
}
