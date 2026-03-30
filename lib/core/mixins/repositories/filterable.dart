import '../../abstracts/models/with_id.dart';
import '../../abstracts/repository.dart';
import '../../abstracts/models/searchable.dart';

mixin CoreMixinsRepositoriesFilterable<T extends CoreModelWithId> on CoreBaseRepository<T> {
  List<T> filter(String query) {
    final q = query.toLowerCase();
    return box.values.cast<T>().where((c) => (c as CoreModelSearchable).searchKey.contains(q)).toList();
  }
}
