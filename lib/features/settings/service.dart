import 'repository.dart';
import 'keys.dart';

class SettingsService {
  final SettingsRepository repo;

  SettingsService(this.repo);

  Future<void> init() async {
    await repo.init();
  }

  T get<T>(SettingKey key, {T? defaultValue}) {
    return repo.get<T>(key, defaultValue: defaultValue) as T;
  }

  Future<void> save(SettingKey key, dynamic value) async {
    await repo.save(key, value);
  }

  Future<void> update(SettingKey key, dynamic value) async {
    await repo.save(key, value);
  }

  bool has(SettingKey key) => repo.has(key);

  Future<void> delete(SettingKey key) async {
    await repo.delete(key);
  }

  Future<String?> getDecryptedMarker() async {
    return await repo.getDecryptedMarker();
  }

  Map<String, dynamic> toMap() {
    return repo.toMap();
  }
}
