import 'package:jxledger/app/exceptions.dart';

import '../../core/abstracts/models/exportable.dart';
import '../../core/abstracts/models/with_id.dart';
import 'keys.dart';

class SettingsModel implements CoreModelWithId, CoreModelExportable {
  final String keyId;
  final SettingType type;
  final dynamic value;

  SettingsModel({required this.keyId, required this.type, required this.value}) {
    SettingKey? key;
    try {
      key = SettingKey.values.firstWhere((k) => k.id == keyId);
    } catch (_) {
      throw ValidationException(AppErrorCode.settingsInvalidValue, "invalid key $keyId", "Not valid settings key");
    }

    if (key.validator != null) {
      final error = key.validator!(value.toString());
      if (error != null) {
        throw ValidationException(
          AppErrorCode.settingsInvalidValue,
          "Settings value is not valid for $keyId: $value",
          "Invalid value provided",
        );
      }
    }
  }

  @override
  String get uuid => keyId;

  @override
  Map<String, dynamic> toJson() {
    return {'keyId': keyId, 'type': type.index, 'value': value};
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    final keyId = json['keyId'] as String;
    final typeIndex = json['type'] as int;
    final type = SettingType.values[typeIndex];
    final value = json['value'];

    return SettingsModel(keyId: keyId, type: type, value: value);
  }

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
