import '../../core/abstracts/models/with_id.dart';
import 'keys.dart';

class SettingsModel implements CoreModelWithId {
  final String keyId;
  final SettingType type;
  final dynamic value;

  SettingsModel({required this.keyId, required this.type, required this.value});

  @override
  String get uuid => keyId;

  static SettingsModel fromLegacy(String keyId, dynamic value) {
    final key = SettingKey.values.where((entry) => entry.id == keyId).firstOrNull;
    final normalizedValue = value is Map && value.isNotEmpty ? value[keyId] ?? value.values.first : value;
    return SettingsModel(keyId: keyId, type: key?.type ?? _inferType(value), value: normalizedValue);
  }

  static SettingType _inferType(dynamic value) {
    if (value is bool) return SettingType.boolean;
    if (value is int) return SettingType.integer;
    if (value is List) return SettingType.list;
    return SettingType.string;
  }
}

extension on Iterable<SettingKey> {
  SettingKey? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
