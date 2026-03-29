import 'package:hive_ce/hive_ce.dart';

import '../../../core/abstracts/repository.dart';
import '../../../core/mixins/repositories/exportable.dart';
import '../../../core/mixins/repositories/id_generator.dart';
import 'model.dart';

class PanelsRepository extends CoreBaseRepository<PanelsModel, String>
    with CoreMixinsRepositoriesIdGenerator<PanelsModel, String>, CoreMixinsRepositoriesExportable<PanelsModel, String> {
  @override
  String get boxName => 'panels_box';

  @override
  get fromJson => PanelsModel.fromJson;

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<PanelsModel>(boxName);
    }
  }
}
