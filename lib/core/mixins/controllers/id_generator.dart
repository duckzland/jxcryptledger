import '../../abstracts/controller.dart';
import '../../abstracts/models/base.dart';
import '../repositories/id_generator.dart';

mixin CoreMixinsControllersIdGenerator<T extends CoreModelBase<K>, K, R extends CoreMixinsRepositoriesIdGenerator<T, K>>
    on CoreBaseController<T, K, R> {
  K generateId() {
    return repo.generateId() as K;
  }
}
