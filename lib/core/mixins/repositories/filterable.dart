import '../../abstracts/models/base.dart';
import '../../abstracts/repository.dart';
import '../../abstracts/models/searchable.dart';

mixin CoreMixinsRepositoriesFilterable<T extends CoreModelBase<K>, K> on CoreBaseRepository<T, K> {
  List<T> filter(String query) {
    final q = query.toLowerCase();
    return box.values.cast<T>().where((c) => (c as CoreModelSearchable).searchKey.contains(q)).toList();
  }
}
