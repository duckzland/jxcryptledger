import '../../core/abstracts/box.dart';
import '../../core/ipc/box/standard.dart';
import '../../core/ipc/event.dart';
import '../../core/log.dart';
import '../encryption/service.dart';
import 'keys.dart';
import 'model.dart';

class SettingsRepository {
  String get boxName => 'settings_box';
  bool initialized = false;

  final EncryptionService _encryption = EncryptionService.instance;

  CoreBaseBox<SettingsModel>? _box;
  CoreBaseBox<SettingsModel> get box {
    return _box ??= CoreIpcBoxStandard<SettingsModel>(boxName);
  }

  set box(CoreBaseBox<SettingsModel> box) {
    _box = box;
  }

  SettingsRepository();

  Future<void> init() async {
    if (initialized) {
      return;
    }
    await box.init();
    initialized = true;
  }

  void receive(CoreIpcBroadcastEvent event) {
    box.receive(event);
  }

  Future<void> save(SettingKey key, dynamic value) async {
    if (value is String && key.validator != null) {
      final error = key.validator!(value);
      if (error != null) return;
    }

    final storedValue = key == SettingKey.vaultInitialized && value is String ? await _encryption.encrypt(value) : value;
    await box.put(key.id, SettingsModel(keyId: key.id, type: key.type, value: storedValue));
  }

  T? get<T>(SettingKey key, {T? defaultValue}) {
    final entry = box.get(key.id);
    final dynamic value = entry?.value;

    if (value == null) {
      return defaultValue ?? key.defaultValue as T?;
    }

    return value as T?;
  }

  Future<String?> getDecryptedMarker() async {
    final entry = box.get(SettingKey.vaultInitialized.id);
    final encrypted = entry?.value;
    if (encrypted == null) return null;
    try {
      return await _encryption.decrypt(encrypted);
    } catch (_) {
      try {
        if (encrypted is List<int>) {
          final tryStr = String.fromCharCodes(encrypted);
          return await _encryption.decrypt(tryStr);
        }
      } catch (_) {}

      try {
        logln("[SettingsRepository] Failed to decrypt marker. Stored type: ${encrypted.runtimeType}");
      } catch (_) {}

      return null;
    }
  }

  bool has(SettingKey key) => box.containsKey(key.id);

  Future<void> delete(SettingKey key) async {
    await box.delete(key.id);
  }

  Map<String, dynamic> toMap() {
    final values = <String, dynamic>{};
    for (final entry in box.items.entries) {
      final model = entry.value as SettingsModel?;
      values[entry.key.toString()] = model?.value;
    }
    return values;
  }
}
