import 'package:hive_ce/hive_ce.dart';
import '../../core/encryption_service.dart';

enum SettingType { string, boolean, integer, list }

enum SettingKey {
  vaultInitialized(
    type: SettingType.string,
    isUserEditable: false, // Internal marker, hide from UI
    label: 'Vault Status',
  ),
  themeMode(type: SettingType.string, isUserEditable: true, label: 'App Theme'),
  currency(
    type: SettingType.string,
    isUserEditable: true,
    label: 'Default Currency',
  ),
  biometricEnabled(
    type: SettingType.boolean,
    isUserEditable: true,
    label: 'Fingerprint/FaceID',
  );

  final SettingType type;
  final bool isUserEditable;
  final String label;

  const SettingKey({
    required this.type,
    required this.isUserEditable,
    required this.label,
  });

  String get id => name;
}

class SettingsRepository {
  static const String boxName = 'settings_box';
  final EncryptionService _encryption = EncryptionService.instance;

  // Use a getter for the box since it's opened during the unlock process
  Box<dynamic> get _box => Hive.box<dynamic>(boxName);

  /// Standard generic save
  /// Usage: repo.save(SettingKey.themeMode, 'dark');
  Future<void> save(SettingKey key, dynamic value) async {
    // If saving the initialization marker, we handle the double-encryption here
    if (key == SettingKey.vaultInitialized && value is String) {
      final encrypted = await _encryption.encrypt(value);
      await _box.put(key.id, encrypted);
    } else {
      await _box.put(key.id, value);
    }
  }

  /// Standard generic load with type safety
  /// Usage: String? theme = repo.get<String>(SettingKey.themeMode);
  T? get<T>(SettingKey key, {T? defaultValue}) {
    final value = _box.get(key.id, defaultValue: defaultValue);

    // Auto-cast to requested type T
    return value as T?;
  }

  /// Specialized load for the vault marker (includes decryption)
  Future<String?> getDecryptedMarker() async {
    final String? encrypted = _box.get(SettingKey.vaultInitialized.id);
    if (encrypted == null) return null;

    try {
      return await _encryption.decrypt(encrypted);
    } catch (_) {
      return null;
    }
  }

  /// Check if a setting exists
  bool has(SettingKey key) => _box.containsKey(key.id);

  /// Delete a specific setting
  Future<void> delete(SettingKey key) async {
    await _box.delete(key.id);
  }

  /// Get all settings as a Map (for debugging or bulk UI state)
  Map<String, dynamic> toMap() {
    return Map<String, dynamic>.from(_box.toMap());
  }
}
