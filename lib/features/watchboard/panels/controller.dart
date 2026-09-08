import 'package:decimal/decimal.dart';

import '../../../core/abstracts/controller.dart';
import '../../../ipc/status/op.dart';
import '../../../ipc/protocol/event.dart';
import '../../../core/math.dart';
import '../../../core/mixins/controllers/exportable.dart';
import '../../../core/mixins/controllers/id_generator.dart';
import '../../../core/mixins/controllers/rateable.dart';
import '../../transactions/repository.dart';
import 'model.dart';
import 'repository.dart';

class PanelsController extends CoreBaseController<PanelsModel, PanelsRepository>
    with
        CoreMixinsControllersIdGenerator<PanelsModel, PanelsRepository>,
        CoreMixinsControllersExportable<PanelsModel, PanelsRepository>,
        CoreMixinsControllersRateable<PanelsModel, PanelsRepository> {
  final TransactionsRepository _txRepo;

  PanelsController(super.repo, this._txRepo);

  @override
  void broadcasterAction(IpcBroadcastEvent event) {
    super.broadcasterAction(event);
    if (event.actionCode == IpcStatusOp.getCode("refreshRates")) {
      if (event.action == "complete") {
        onRatesUpdated();
        load();
      }
    }
  }

  @override
  Future<void> processNewRate(PanelsModel tx, Decimal newRate) async {
    if (newRate != tx.rate) {
      tx.setRate(newRate);
      await repo.update(tx);
      load();
    }
  }

  PanelsModel? getLinked(String linkKey) {
    for (final wx in items) {
      if (wx.meta['txLink'] == linkKey) {
        return wx;
      }
    }

    return null;
  }

  bool hasLinked() {
    for (final wx in items) {
      if (wx.meta['txLink'] != null && wx.meta['txLink'] != "") {
        return true;
      }
    }

    return false;
  }

  int nextHighestOrder() {
    int maxOrder = 0;

    for (final wx in items) {
      final raw = wx.order;

      if (raw != null) {
        final value = raw;
        if (value > maxOrder) {
          maxOrder = value;
        }
      }
    }

    return maxOrder + 1;
  }

  Future<bool> updateLinked() async {
    final txs = _txRepo.extract();
    final grouped = <String, Decimal>{};
    final groupedByBalance = <int, Decimal>{};
    int updateCount = 0;

    for (final tx in txs) {
      if (!tx.isActive && !tx.isPartial) continue;

      final pairKey = "${tx.srId}-${tx.rrId}";
      grouped[pairKey] = Math.add(grouped[pairKey] ?? Decimal.zero, tx.srAmount);
      groupedByBalance[tx.rrId] = Math.add(groupedByBalance[tx.rrId] ?? Decimal.zero, tx.balance);
    }

    for (final wx in items) {
      final txlink = wx.meta['txLink'] ?? "";
      if (txlink.isEmpty) {
        continue;
      }

      final match = RegExp(r'.*?(\d+)-(\d+)$').firstMatch(txlink);
      if (match == null) {
        continue;
      }

      final srid = int.tryParse(match.group(1) ?? "-1") ?? -1;
      final rrid = int.tryParse(match.group(2) ?? "-1") ?? -1;

      Decimal totalAmount;

      if (txlink.contains("active-screen-")) {
        totalAmount = grouped["$srid-$rrid"] ?? Decimal.zero;
      } else if (txlink.contains("overview-screen-")) {
        totalAmount = groupedByBalance[rrid] ?? Decimal.zero;
      } else {
        continue;
      }

      if (totalAmount == Decimal.zero) {
        final meta = {...wx.meta}..remove('txLink');
        await update(wx.copyWith(meta: meta));
        updateCount++;
      } else if (wx.srAmount != totalAmount) {
        await update(wx.copyWith(srAmount: totalAmount));
        updateCount++;
      }
    }

    return updateCount > 0;
  }

  Future<void> wipeLinked() async {
    for (final wx in items) {
      final txlink = wx.meta['txLink'] ?? "";
      if (txlink.isEmpty) {
        continue;
      }

      await remove(wx);
    }

    load();
  }

  void updateOrder(List<PanelsModel> newOrder) {
    for (var i = 0; i < newOrder.length; i++) {
      newOrder[i].order = i;
      repo.update(newOrder[i]);
    }

    load();
  }

  bool isBothEqual(PanelsModel a, PanelsModel b) {
    return a.tid == b.tid &&
        a.srAmount == b.srAmount &&
        a.srId == b.srId &&
        a.rrId == b.rrId &&
        a.digit == b.digit &&
        a.rate == b.rate &&
        a.order == b.order &&
        a.meta.length == b.meta.length &&
        a.meta.keys.every((k) => b.meta.containsKey(k) && a.meta[k] == b.meta[k]);
  }
}
