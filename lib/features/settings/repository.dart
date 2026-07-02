import 'dart:convert';

import '../../core/abstracts/repository.dart';
import '../../core/log.dart';
import '../../core/mixins/repositories/exportable.dart';
import '../system/encryption/service.dart';
import 'keys.dart';
import 'model.dart';

class SettingsRepository extends CoreBaseRepository<SettingsModel> with CoreMixinsRepositoriesExportable<SettingsModel> {
  @override
  String get boxName => 'settings_box';

  @override
  get fromJson => SettingsModel.fromJson;

  @override
  Future<String> export() async {
    final items = extract();
    final jsonList = items
        .cast<SettingsModel>()
        .where((e) {
          SettingKey? key;
          try {
            key = SettingKey.values.firstWhere((k) => k.id == e.keyId);
          } catch (_) {
            key = null;
          }
          return key?.isUserEditable ?? false;
        })
        .map((e) => e.toJson())
        .toList();
    return jsonEncode(jsonList);
  }

  @override
  Future<int> clear() async {
    final editableKeys = SettingKey.values.where((k) => k.isUserEditable).toList();
    for (var key in editableKeys) {
      final def = key.defaultValue;
      await save(key, def);
    }

    onAction();
    return 0;
  }

  @override
  bool isEmpty() {
    final items = extract();
    final filtered = items.where((item) {
      SettingKey? key;
      try {
        key = SettingKey.values.firstWhere((k) => k.id == item.keyId);
        return item.value != key.defaultValue && key.isUserEditable;
      } catch (_) {}
      return false;
    }).toList();

    return filtered.isEmpty;
  }

  @override
  Future<void> import(String rawJson) async {
    final decoded = jsonDecode(rawJson) as List<dynamic>;
    final txs = decoded.map((e) => SettingsModel.fromJson(e as Map<String, dynamic>)).where((tx) {
      SettingKey? key;
      try {
        key = SettingKey.values.firstWhere((k) => k.id == tx.keyId);
      } catch (_) {
        key = null;
      }
      return key?.isUserEditable ?? false;
    }).toList();

    for (final tx in txs) {
      await box.put(tx.uuid, tx);
    }
  }

  final SystemEncryptionService _encryption = SystemEncryptionService.instance;

  Future<void> save(SettingKey key, dynamic value) async {
    if (value is String && key.validator != null) {
      final error = key.validator!(value);
      if (error != null) return;
    }

    final storedValue = key == SettingKey.vaultInitialized && value is String ? await _encryption.encrypt(value) : value;
    await box.put(key.id, SettingsModel(keyId: key.id, type: key.type, value: storedValue));
  }

  T? getByKey<T>(SettingKey key, {T? defaultValue}) {
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

  Future<void> deleteByKey(SettingKey key) async {
    // Dont really allow to delete!
    if (key.isUserEditable) {
      await save(key, key.defaultValue);
    }
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
