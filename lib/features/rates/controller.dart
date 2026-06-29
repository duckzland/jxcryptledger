import 'dart:async';

import '../../core/abstracts/controller.dart';
import 'model.dart';
import 'repository.dart';
import 'service.dart';

class RatesController extends CoreBaseController<RatesModel, RatesRepository> {
  final RatesService service;

  RatesController(super.repo, this.service);

  bool get isFetching => service.isFetching;
  bool get hasRates => service.hasRates;

  @override
  Future<void> init() async {
    await repo.init();
    await service.init();
    load();
    emitterListen();
  }

  double getStoredRate(int sourceId, int targetId, {bool throwable = false}) {
    return service.getStoredRate(sourceId, targetId, throwable: throwable);
  }

  void addQueue(int sourceId, int targetId, {bool force = true}) {
    service.addQueue(sourceId, targetId, force: force);
  }

  Future<void> refreshRates() async {
    await service.refreshRates();
    load();
  }

  Future<void> deleteById(int sourceId, int targetId) async {
    await service.deleteById(sourceId, targetId);
  }
}
