import 'package:hive_ce/hive_ce.dart';

import '../../core/abstracts/repository.dart';
import '../../core/log.dart';
import '../../core/mixins/repositories/id_generator.dart';
import 'model.dart';

class RatesRepository extends CoreBaseRepository<RatesModel, String> with CoreMixinsRepositoriesIdGenerator<RatesModel, String> {
  @override
  String get boxName => 'rates_box';

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<RatesModel>(boxName);
    }
  }

  @override
  String generateId() {
    return "";
  }

  @override
  Future<void> add(RatesModel tx) async {
    final rateWithTimestamp = tx.copyWith(timestamp: DateTime.now().microsecondsSinceEpoch);
    await box.put(tx.uuid, rateWithTimestamp);
  }

  RatesModel? getPair(int sourceId, int targetId) {
    final key = '$sourceId-$targetId';
    return box.get(key);
  }

  Future<void> deletePair(int sourceId, int targetId) async {
    final key = '$sourceId-$targetId';
    await box.delete(key);
  }

  Future<void> cleanupOldRates({Duration olderThan = const Duration(days: 1)}) async {
    logln('[RATES] Cleaning old rates.');

    final box = Hive.box<RatesModel>(boxName);
    final nowEpoch = DateTime.now().microsecondsSinceEpoch;
    final keysToDelete = <dynamic>[];

    for (int i = 0; i < box.length; i++) {
      final rate = box.getAt(i);
      if (rate != null) {
        final ageMs = nowEpoch - rate.timestamp;
        if (ageMs > olderThan.inMilliseconds) {
          keysToDelete.add(box.keyAt(i));
        }
      }
    }

    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }
}
