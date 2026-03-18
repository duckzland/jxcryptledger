import 'package:hive_ce/hive_ce.dart';
import '../../core/abstracts/repository.dart';
import '../../core/mixins/exportable.dart';
import '../../core/mixins/id_generator.dart';
import 'model.dart';

class WatchersRepository extends CoreBaseRepository<WatchersModel, String>
    with CoreMixinsIdGenerator<WatchersModel, String>, CoreMixinsExportable<WatchersModel, String> {
  @override
  String get boxName => 'watchers_box';

  @override
  get fromJson => WatchersModel.fromJson;

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<WatchersModel>(boxName);
    }
  }

  Future<void> saveAll(List<WatchersModel> wx) async {
    await box.clear();
    for (final w in wx) {
      await box.put(w.wid, w);
    }
  }
}
