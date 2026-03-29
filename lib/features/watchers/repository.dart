import 'package:hive_ce/hive_ce.dart';
import '../../core/abstracts/repository.dart';
import '../../core/mixins/repositories/exportable.dart';
import '../../core/mixins/repositories/id_generator.dart';
import 'model.dart';

class WatchersRepository extends CoreBaseRepository<WatchersModel, String>
    with CoreMixinsRepositoriesIdGenerator<WatchersModel, String>, CoreMixinsRepositoriesExportable<WatchersModel, String> {
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
