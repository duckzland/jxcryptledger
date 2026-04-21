import '../../../core/abstracts/controller.dart';
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
  void init() {
    scheduleRates();
  }

  @override
  Future<void> processNewRate(PanelsModel tx, double newRate) async {
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
    final Map<String, double> grouped = {};
    int updateCount = 0;

    for (final tx in txs) {
      final pairKey = "${tx.srId}-${tx.rrId}";
      grouped[pairKey] = (grouped[pairKey] ?? 0.0) + tx.srAmount;
    }

    for (final wx in items) {
      final txlink = wx.meta['txLink'] ?? "";
      if (txlink.isEmpty) {
        continue;
      }

      if (txlink.contains("active-screen-")) {
        final regex = RegExp(r'active-screen-(\d+)-(\d+)');
        final match = regex.firstMatch(txlink);

        if (match != null) {
          final srid = match.group(1);
          final rrid = match.group(2);
          final pairKey = "$srid-$rrid";
          final totalAmount = grouped[pairKey] ?? 0.0;

          if (wx.srAmount != totalAmount) {
            final nwx = wx.copyWith(srAmount: totalAmount);
            await update(nwx);
            updateCount += 1;
          }
        }
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
}
