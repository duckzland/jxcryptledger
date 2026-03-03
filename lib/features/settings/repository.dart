import 'package:hive_ce/hive_ce.dart';

import '../encryption/service.dart';
import 'keys.dart';

class SettingsRepository {
  static const String boxName = 'settings_box';
  final EncryptionService _encryption = EncryptionService.instance;

  Box<dynamic> get _box => Hive.box<dynamic>(boxName);

  Future<void> save(SettingKey key, dynamic value) async {
    if (value is String && key.validator != null) {
      final error = key.validator!(value);
      if (error != null) return;
    }

    if (key == SettingKey.vaultInitialized && value is String) {
      final encrypted = await _encryption.encrypt(value);
      await _box.put(key.id, encrypted);
    } else {
      await _box.put(key.id, value);
    }
  }

  T? get<T>(SettingKey key, {T? defaultValue}) {
    final value = _box.get(key.id, defaultValue: defaultValue ?? key.defaultValue);
    return value as T?;
  }

  Future<String?> getDecryptedMarker() async {
    final encrypted = _box.get(SettingKey.vaultInitialized.id);
    if (encrypted == null) return null;
    try {
      return await _encryption.decrypt(encrypted);
    } catch (_) {
      return null;
    }
  }

  bool has(SettingKey key) => _box.containsKey(key.id);

  Future<void> delete(SettingKey key) async {
    await _box.delete(key.id);
  }

  Map<String, dynamic> toMap() {
    return Map<String, dynamic>.from(_box.toMap());
  }
}
