import 'package:hive_ce/hive_ce.dart';

import '../../../core/abstracts/repository.dart';
import '../../../core/mixins/id_generator.dart';
import 'model.dart';

class TickersRepository extends CoreBaseRepository<TickersModel, String> with CoreMixinsIdGenerator<TickersModel, String>  {
  @override
  String get boxName => 'tickers_box';

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<TickersModel>(boxName);
    }
  }

  Future<void> updateByType(int type, String newVal) async {
    TickersModel? model;
    try {
      model = box.values.firstWhere((m) => m.type == type);
    } catch (_) {
      return;
    }

    model.value = newVal;
    await box.put(model.tid, model);
  }
}
