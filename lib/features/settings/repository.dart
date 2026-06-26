import '../../core/ipc/box/dynamic.dart';
import '../encryption/service.dart';
import 'keys.dart';

class SettingsRepository {
  static const String boxName = 'settings_box';
  final EncryptionService _encryption = EncryptionService.instance;
  final CoreIpcBoxDynamic box;

  SettingsRepository() : box = CoreIpcBoxDynamic(boxName);

  Future<void> init() async {
    await box.init();
  }

  Future<void> save(SettingKey key, dynamic value) async {
    if (value is String && key.validator != null) {
      final error = key.validator!(value);
      if (error != null) return;
    }

    if (key == SettingKey.vaultInitialized && value is String) {
      final encrypted = await _encryption.encrypt(value);
      await box.put(key.id, encrypted);
    } else {
      await box.put(key.id, value);
    }
  }

  T? get<T>(SettingKey key, {T? defaultValue}) {
    final value = box.get(key.id);

    if (value == null) {
      return defaultValue ?? key.defaultValue as T?;
    }

    if (value is Map) {
      final inner = value[key.id];
      if (inner == null) {
        return defaultValue ?? key.defaultValue as T?;
      }
      return inner as T?;
    }

    return value as T?;
  }

  Future<String?> getDecryptedMarker() async {
    final encrypted = box.get(SettingKey.vaultInitialized.id);
    if (encrypted == null) return null;
    try {
      return await _encryption.decrypt(encrypted);
    } catch (_) {
      return null;
    }
  }

  bool has(SettingKey key) => box.containsKey(key.id);

  Future<void> delete(SettingKey key) async {
    await box.delete(key.id);
  }

  Map<String, dynamic> toMap() {
    return Map<String, dynamic>.from(box.toMap());
  }
}
