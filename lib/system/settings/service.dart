import '../../core/abstracts/service.dart';
import 'model.dart';
import 'repository.dart';
import 'keys.dart';

class SettingsService extends CoreBaseService<SettingsModel, SettingsRepository> {
  SettingsService(super.repo);

  T getByKey<T>(SettingKey key, {T? defaultValue}) {
    return repo.getByKey<T>(key, defaultValue: defaultValue) as T;
  }

  Future<void> save(SettingKey key, dynamic value) async {
    await repo.save(key, value);
  }

  Future<void> updateByKey(SettingKey key, dynamic value) async {
    await repo.save(key, value);
  }

  bool has(SettingKey key) => repo.has(key);

  Future<void> deleteByKey(SettingKey key) async {
    await repo.deleteByKey(key);
  }

  Future<String?> getDecryptedMarker() async {
    return await repo.getDecryptedMarker();
  }

  Map<String, dynamic> toMap() {
    return repo.toMap();
  }
}
