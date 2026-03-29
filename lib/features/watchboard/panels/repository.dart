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
}
