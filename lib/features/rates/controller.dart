import 'dart:async';

import 'package:decimal/decimal.dart';

import '../../core/abstracts/controller.dart';
import '../../ipc/status/op.dart';
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

    if (event.actionCode == IpcStatusOp.getCode("refreshRates")) {
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

  Decimal getStoredRate(int sourceId, int targetId, {bool throwable = false}) {
    if (sourceId == targetId) {
      return Decimal.one;
    }

    if (!throwable) {
      if (!isValidPair(sourceId, targetId)) return Decimal.fromInt(-9999);
    } else {
      validateIds(sourceId, targetId);
    }

    final existing = repo.get("$sourceId-$targetId");
    return existing?.rate ?? Decimal.fromInt(-9999);
  }

  void addQueue(int sourceId, int targetId, {bool force = true}) {
    if (!isValidPair(sourceId, targetId)) return;
    ipcClient.send(op: IpcStatusOp.getCode("addRateQueue"), action: "$sourceId-$targetId", key: force);
  }

  Future<void> refreshRates() async {
    await ipcClient.send(op: IpcStatusOp.getCode("refreshRates"), action: "action", key: "refresh_rates");
  }

  Future<void> deleteById(int sourceId, int targetId) async {
    await repo.delete("$sourceId-$targetId");
  }
}
