import '../../abstracts/controller.dart';
import '../../abstracts/models/base.dart';
import '../repositories/id_generator.dart';

mixin CoreMixinsControllersIdGenerator<T extends CoreModelBase, R extends CoreMixinsRepositoriesIdGenerator<T>>
    on CoreBaseController<T, R> {
  String generateId() {
    return repo.generateId();
  }
}
