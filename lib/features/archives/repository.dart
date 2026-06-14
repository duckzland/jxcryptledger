import '../../core/abstracts/repository.dart';
import '../../core/mixins/repositories/exportable.dart';
import '../../core/mixins/repositories/id_generator.dart';
import 'model.dart';

class ArchivesRepository extends CoreBaseRepository<ArchivesModel>
    with CoreMixinsRepositoriesIdGenerator<ArchivesModel>, CoreMixinsRepositoriesExportable<ArchivesModel> {
  @override
  String get boxName => 'archives_box';

  @override
  get fromJson => ArchivesModel.fromJson;
}
