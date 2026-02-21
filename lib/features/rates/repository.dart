import 'package:hive_ce/hive_ce.dart';

import 'model.dart';

class RatesRepository {
  static const String boxName = 'rates_box';

  Future<void> init() async {
    await Hive.openBox<RatesModel>(boxName);
  }

  Future<void> add(RatesModel rate) async {
    final box = Hive.box<RatesModel>(boxName);
    final key = '${rate.sourceId}-${rate.targetId}';
    final rateWithTimestamp = rate.copyWith(timestamp: DateTime.now().millisecondsSinceEpoch);
    await box.put(key, rateWithTimestamp);
  }

  Future<List<RatesModel>> getAll() async {
    final box = Hive.box<RatesModel>(boxName);
    return box.values.toList();
  }

  Future<RatesModel?> get(int sourceId, int targetId) async {
    final box = Hive.box<RatesModel>(boxName);
    final key = '$sourceId-$targetId';
    return box.get(key);
  }

  Future<void> delete(int sourceId, int targetId) async {
    final box = Hive.box<RatesModel>(boxName);
    final key = '$sourceId-$targetId';
    await box.delete(key);
  }

  Future<void> clear() async {
    final box = Hive.box<RatesModel>(boxName);
    await box.clear();
  }

  Future<void> cleanupOldRates({Duration olderThan = const Duration(days: 1)}) async {
    final box = Hive.box<RatesModel>(boxName);
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;
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

  bool hasAny() {
    final box = Hive.box<RatesModel>(boxName);
    return box.isNotEmpty;
  }
}
