import 'package:flutter/foundation.dart';
import '../../core/runtime/runtime.dart';
import 'repository.dart';
import 'keys.dart';

class SettingsController extends ChangeNotifier {
  final SettingsRepository repo;

  SettingsController(this.repo);

  Future<void> init() async {
    await repo.init();
  }

  T get<T>(SettingKey key, {T? defaultValue}) {
    return repo.get<T>(key, defaultValue: defaultValue) as T;
  }

  void load() {
    if (!CoreRuntime.instance.isServer()) {
      notifyListeners();
    }
  }

  Future<void> update(SettingKey key, dynamic value) async {
    await repo.save(key, value);
    load();
  }

  Future<String?> getDecryptedMarker() async {
    return await repo.getDecryptedMarker();
  }
}
