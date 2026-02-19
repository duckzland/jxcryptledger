import 'package:flutter/foundation.dart';
import 'repository.dart';

class SettingsController extends ChangeNotifier {
  final SettingsRepository _repo;

  SettingsController(this._repo);

  /// Get a setting with type safety
  /// Example: controller.get<String>(SettingKey.currency)
  T get<T>(SettingKey key, {T? defaultValue}) {
    return _repo.get<T>(key, defaultValue: defaultValue) as T;
  }

  /// Update a setting and notify the UI
  /// Example: controller.update(SettingKey.themeMode, 'dark')
  Future<void> update(SettingKey key, dynamic value) async {
    await _repo.save(key, value);

    // This tells all listeners (like your Settings Screen) to rebuild
    notifyListeners();
  }

  /// Convenience getter for theme
  String get themeMode =>
      get<String>(SettingKey.themeMode, defaultValue: 'system');

  /// Convenience getter for currency
  String get currency => get<String>(SettingKey.currency, defaultValue: 'USD');

  /// If you still need a 'search' for settings labels later,
  /// you can implement it by filtering the repo.toMap() keys.
  /// For now, simple key-value settings usually don't need an Isolate search.
}
