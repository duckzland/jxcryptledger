import '../../../core/abstracts/repository.dart';
import '../../../core/mixins/repositories/id_generator.dart';
import 'model.dart';

class TickersRepository extends CoreBaseRepository<TickersModel> with CoreMixinsRepositoriesIdGenerator<TickersModel> {
  @override
  String get boxName => 'tickers_box';

  Future<void> updateAllByTypes(List<({int type, String newVal, String? title})> updates) async {
    if (updates.isEmpty) return;

    final byType = {for (final m in box.values) m.type: m};

    final payload = <TickersModel>[];

    for (final item in updates) {
      var model = byType[item.type];
      if (model == null) continue;

      if (item.title != null) {
        model = model.copyWith(title: item.title);
      }

      model.value = item.newVal;
      payload.add(model);
    }

    if (payload.isNotEmpty) {
      await box.addAll(payload);
    }
  }

  Future<void> updateByType(int type, String newVal, {String? title}) async {
    TickersModel? model;
    try {
      model = box.values.firstWhere((m) => m.type == type);
    } catch (_) {
      return;
    }

    if (title != null) {
      model = model.copyWith(title: title);
    }

    model.value = newVal;
    await box.put(model.uuid, model);
  }
}
