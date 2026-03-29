import '../../abstracts/controller.dart';
import '../../abstracts/model.dart';
import '../repositories/id_generator.dart';

mixin CoreMixinsControllersIdGenerator<T extends CoreBaseModel<K>, K, R extends CoreMixinsRepositoriesIdGenerator<T, K>>
    on CoreBaseController<T, K, R> {
  K generateId() {
    return repo.generateId() as K;
  }
}
