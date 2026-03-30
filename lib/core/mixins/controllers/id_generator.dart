import '../../abstracts/controller.dart';
import '../../abstracts/models/with_id.dart';
import '../repositories/id_generator.dart';

mixin CoreMixinsControllersIdGenerator<T extends CoreModelWithId, R extends CoreMixinsRepositoriesIdGenerator<T>>
    on CoreBaseController<T, R> {
  String generateId() {
    return repo.generateId();
  }
}
