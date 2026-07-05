import 'dart:async';

import '../../core/abstracts/controller.dart';
import '../../ipc/action.dart';
import '../../ipc/event.dart';

import 'mixins/helper.dart';
import 'model.dart';
import 'repository.dart';

class RatesController extends CoreBaseController<RatesModel, RatesRepository> with RatesMixinsHelper {
  RatesController(super.repo);

  late bool isFetching;
  late bool hasRates;

  @override
  Future<void> init() async {
    super.init();
    isFetching = false;
    hasRates = !repo.isEmpty();
  }

  @override
  void broadcasterAction(IpcBroadcastEvent event) {
    super.broadcasterAction(event);

    if (event.action == repo.boxName) {
      if (hasRates != !repo.isEmpty()) {
        hasRates = !repo.isEmpty();
        debounceNotify();
      }
    }

    if (event.actionCode == IpcAction.refreshRates) {
      if (event.action == "start") {
        if (!isFetching) {
          isFetching = true;
          hasRates = !repo.isEmpty();
          debounceNotify();
        }
      }

      if (event.action == "complete") {
        isFetching = false;
        hasRates = !repo.isEmpty();
        debounceNotify();
      }

      return;
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
    ipcClient.send(op: IpcAction.addRateQueue, action: "$sourceId-$targetId", key: force);
  }

  Future<void> refreshRates() async {
    await ipcClient.send(op: IpcAction.refreshRates, action: "action", key: "refresh_rates");
  }

  Future<void> deleteById(int sourceId, int targetId) async {
    await repo.delete("$sourceId-$targetId");
  }
}
