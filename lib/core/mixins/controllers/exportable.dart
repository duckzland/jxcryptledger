import '../../abstracts/controller.dart';
import '../../abstracts/models/base.dart';
import '../repositories/exportable.dart';

mixin CoreMixinsControllersExportable<T extends CoreModelBase, R extends CoreMixinsRepositoriesExportable<T>> on CoreBaseController<T, R> {
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
