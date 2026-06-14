import '../../core/abstracts/repository.dart';
import '../../core/mixins/repositories/exportable.dart';
import '../../core/mixins/repositories/id_generator.dart';
import 'model.dart';

class WatchersRepository extends CoreBaseRepository<WatchersModel>
    with CoreMixinsRepositoriesIdGenerator<WatchersModel>, CoreMixinsRepositoriesExportable<WatchersModel> {
  @override
  String get boxName => 'watchers_box';

  @override
  get fromJson => WatchersModel.fromJson;
}
