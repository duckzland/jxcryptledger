import '../mixins/box.dart';
import 'models/with_id.dart';
import 'repository.dart';

abstract class CoreBaseService<T extends CoreModelWithId, R extends CoreBaseRepository<T>> with CoreMixinsBox<T> {
  @override
  final R repo;

  CoreBaseService(this.repo);

  Future<void> init() async {
    repo.init();
  }

  T? findNew(List<T> oldItems) {
    final items = repo.extract();
    final oldIds = oldItems.map((t) => t.uuid).toSet();
    final addedIds = items.map((t) => t.uuid).where((id) => !oldIds.contains(id));

    if (addedIds.isEmpty) {
      return null;
    }

    return items.firstWhere((el) => el.uuid == addedIds.first);
  }
}
