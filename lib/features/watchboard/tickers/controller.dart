import '../../../core/abstracts/controller.dart';
import '../../../core/mixins/controllers/id_generator.dart';
import 'model.dart';
import 'repository.dart';
import 'service.dart';

class TickersController extends CoreBaseController<TickersModel, TickersRepository>
    with CoreMixinsControllersIdGenerator<TickersModel, TickersRepository> {
  final TickersService service;

  TickersController(super.repo, this.service);

  @override
  Future<void> init() async {
    await service.init();
    load();
    emitterListen();
  }

  Future<void> updateByType(int type, String newVal) async {
    await repo.updateByType(type, newVal);
    load();
  }

  Future<void> populate({bool refresh = true, bool fetchRate = true}) async {
    await service.populate(fetchRate: fetchRate);

    if (refresh) {
      load();
    }
  }

  Future<void> refreshRates() async {
    await service.refreshRates();
    load();
  }

  void updateOrder(List<TickersModel> newOrder) {
    for (var i = 0; i < newOrder.length; i++) {
      newOrder[i].order = i;
      repo.update(newOrder[i]);
    }

    load();
  }

  bool isBothEqual(TickersModel a, TickersModel b) {
    return a.tid == b.tid &&
        a.type == b.type &&
        a.format == b.format &&
        a.title == b.title &&
        a.order == b.order &&
        a.value == b.value &&
        a.meta.length == b.meta.length &&
        a.meta.keys.every((k) => b.meta.containsKey(k) && a.meta[k] == b.meta[k]);
  }
}
