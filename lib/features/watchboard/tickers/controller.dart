import 'package:jxledger/features/watchboard/tickers/mixins/helper.dart';

import '../../../core/abstracts/controller.dart';
import '../../../core/mixins/controllers/id_generator.dart';
import 'model.dart';
import 'repository.dart';

class TickersController extends CoreBaseController<TickersModel, TickersRepository>
    with CoreMixinsControllersIdGenerator<TickersModel, TickersRepository>, TickersMixinsHelper {
  TickersController(super.repo);

  Future<void> updateByType(int type, String newVal) async {
    await repo.updateByType(type, newVal);
    load();
  }

  Future<void> populate({bool refresh = true, bool fetchRate = true}) async {
    for (final tx in defaultTickers) {
      await repo.add(tx);
    }

    if (refresh) {
      load();
    }

    if (fetchRate) {
      refreshRates();
    }
  }

  Future<void> refreshRates() async {
    await ipcClient.send(op: 0x16, box: "action");
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
