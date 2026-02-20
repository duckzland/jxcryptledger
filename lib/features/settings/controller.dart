import 'package:flutter/foundation.dart';
import 'repository.dart';

class SettingsController extends ChangeNotifier {
  final SettingsRepository _repo;

  SettingsController(this._repo);

  T get<T>(SettingKey key, {T? defaultValue}) {
    return _repo.get<T>(key, defaultValue: defaultValue) as T;
  }

  Future<void> update(SettingKey key, dynamic value) async {
    await _repo.save(key, value);
    notifyListeners();
  }
}
