import 'dart:async';

import '../../core/abstracts/controller.dart';
import '../../core/ipc/event.dart';
import '../../core/mixins/broadcaster.dart';

import 'mixins/helper.dart';
import 'model.dart';
import 'repository.dart';

class RatesController extends CoreBaseController<RatesModel, RatesRepository> with CoreMixinsBroadcaster, RatesMixinsHelper {
  RatesController(super.repo);

  late bool isFetching;
  late bool hasRates;

  @override
  Future<void> init() async {
    await repo.init();

    isFetching = false;
    hasRates = !repo.isEmpty();

    load();
    emitterListen();
    broadcasterListen();
  }

  @override
  void broadcasterAction(CoreIpcBroadcastEvent event) {
    if (event.op == 0x10) {
      if (event.boxName == "start") {
        isFetching = true;
        emitterEmit(repo.boxName);
        hasRates = !repo.isEmpty();
      }

      if (event.boxName == "complete") {
        isFetching = false;
        emitterEmit(repo.boxName);
        hasRates = !repo.isEmpty();
      }
    }
  }

  double getStoredRate(int sourceId, int targetId, {bool throwable = false}) {
    if (sourceId == targetId) {
      return 1;
    }

    if (!throwable) {
      if (!isValidPair(sourceId, targetId)) return -9999;
    } else {
      validateIds(sourceId, targetId);
    }

    final existing = repo.get("$sourceId-$targetId");
    return existing?.rate.toDouble() ?? -9999;
  }

  void addQueue(int sourceId, int targetId, {bool force = true}) {
    if (!isValidPair(sourceId, targetId)) return;
    ipcClient.send(op: 0x15, box: "$sourceId-$targetId", key: force);
  }

  Future<void> refreshRates() async {
    await ipcClient.send(op: 0x10, box: "action", key: "refresh_rates");
  }

  Future<void> deleteById(int sourceId, int targetId) async {
    await repo.delete("$sourceId-$targetId");
  }
}
