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

    await box.put(key, rate);
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

  bool hasAny() {
    final box = Hive.box<RatesModel>(boxName);
    return box.isNotEmpty;
  }
}
