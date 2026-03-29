import '../../abstracts/controller.dart';
import '../../abstracts/models/base.dart';
import '../../abstracts/models/rateable.dart';
import '../../abstracts/repository.dart';

mixin CoreMixinsControllersRateable<T extends CoreModelBase<K>, K, R extends CoreBaseRepository<T, K>> on CoreBaseController<T, K, R> {
  List<String> getAllRateID() {
    final ids = <String>[];

    for (final tx in items) {
      final r = tx as CoreModelRateable;
      ids.add("${r.srId}-${r.rrId}");
      ids.add("${r.rrId}-${r.srId}");
    }

    return ids;
  }
}
