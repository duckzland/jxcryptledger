import '../../../core/abstracts/repository.dart';
import '../../../core/mixins/repositories/exportable.dart';
import '../../../core/mixins/repositories/id_generator.dart';
import 'model.dart';

class PanelsRepository extends CoreBaseRepository<PanelsModel>
    with CoreMixinsRepositoriesIdGenerator<PanelsModel>, CoreMixinsRepositoriesExportable<PanelsModel> {
  @override
  String get boxName => 'panels_box';

  @override
  get fromJson => PanelsModel.fromJson;
}
