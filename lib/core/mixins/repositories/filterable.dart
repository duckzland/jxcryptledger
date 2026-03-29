import '../../abstracts/models/base.dart';
import '../../abstracts/repository.dart';
import '../../abstracts/models/searchable.dart';

mixin CoreMixinsRepositoriesFilterable<T extends CoreModelBase> on CoreBaseRepository<T> {
  List<T> filter(String query) {
    final q = query.toLowerCase();
    return box.values.cast<T>().where((c) => (c as CoreModelSearchable).searchKey.contains(q)).toList();
  }
}
