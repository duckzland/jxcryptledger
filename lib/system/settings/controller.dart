import 'package:jxledger/core/abstracts/controller.dart';
import '../../core/mixins/controllers/exportable.dart';
import 'model.dart';
import 'repository.dart';
import 'keys.dart';

class SettingsController extends CoreBaseController<SettingsModel, SettingsRepository>
    with CoreMixinsControllersExportable<SettingsModel, SettingsRepository> {
  SettingsController(super.repo);

  T getByKey<T>(SettingKey key, {T? defaultValue}) {
    return repo.getByKey<T>(key, defaultValue: defaultValue) as T;
  }

  Future<void> updateByKey(SettingKey key, dynamic value) async {
    await repo.save(key, value);
    load();
  }

  Future<String?> getDecryptedMarker() async {
    return await repo.getDecryptedMarker();
  }
}
