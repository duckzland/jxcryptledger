import 'package:hive_ce/hive_ce.dart';
import '../../core/encryption_service.dart';

typedef Validator = String? Function(String value);

enum SettingType { string, boolean, integer, list }

enum SettingKey {
  dataEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'Cryptos Endpoint',
    defaultValue:
        "https://s3.coinmarketcap.com/generated/core/crypto/cryptos.json",
    validator: _validateUrl,
    hintText: "https://example.com/cryptos.json",
  ),

  exchangeEndpoint(
    type: SettingType.string,
    isUserEditable: true,
    label: 'Exchange Endpoint',
    defaultValue:
        "https://api.coinmarketcap.com/data-api/v3/tools/price-conversion",
    validator: _validateUrl,
    hintText: "https://example.com/exchange",
  ),

  vaultInitialized(
    type: SettingType.string,
    isUserEditable: false,
    label: 'Vault Status',
    defaultValue: "",
    validator: null,
    hintText: "",
  );

  final SettingType type;
  final bool isUserEditable;
  final String label;
  final String defaultValue;
  final Validator? validator;
  final String hintText;

  const SettingKey({
    required this.type,
    required this.isUserEditable,
    required this.label,
    required this.defaultValue,
    required this.validator,
    required this.hintText,
  });

  String get id => name;
}

String? _validateUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return "Invalid URL";
  }
  return null;
}

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
    final value = _box.get(
      key.id,
      defaultValue: defaultValue ?? key.defaultValue,
    );
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
