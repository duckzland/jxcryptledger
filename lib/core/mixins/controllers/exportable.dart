import '../../abstracts/controller.dart';
import '../../abstracts/model.dart';
import '../repositories/exportable.dart';

mixin CoreMixinsControllersExportable<T extends CoreBaseModel<K>, K, R extends CoreMixinsRepositoriesExportable<T, K>>
    on CoreBaseController<T, K, R> {
  Future<String> exportDatabase() async {
    try {
      return await repo.export();
    } catch (e) {
      return '';
    }
  }

  Future<void> importDatabase(String rawJson) async {
    await repo.import(rawJson);
    load();
  }
}
