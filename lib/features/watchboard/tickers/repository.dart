import '../../../core/abstracts/repository.dart';
import '../../../core/mixins/repositories/id_generator.dart';
import 'model.dart';

class TickersRepository extends CoreBaseRepository<TickersModel, String> with CoreMixinsRepositoriesIdGenerator<TickersModel, String> {
  @override
  String get boxName => 'tickers_box';

  Future<void> updateByType(int type, String newVal) async {
    TickersModel? model;
    try {
      model = box.values.firstWhere((m) => m.type == type);
    } catch (_) {
      return;
    }

    model.value = newVal;
    await box.put(model.uuid, model);
  }
}
