import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';
import 'keys.dart';

class SettingsAdapter extends TypeAdapter<Map<dynamic, dynamic>> {
  @override
  final int typeId = 8;

  @override
  Map<dynamic, dynamic> read(BinaryReader reader) {
    final int length = reader.readInt();
    final Map<dynamic, dynamic> resultDataMap = {};

    for (var i = 0; i < length; i++) {
      final String keyId = reader.readString();

      final SettingKey key = SettingKey.values.firstWhere(
        (k) => k.id == keyId,
        orElse: () => throw FormatException("Unknown SettingKey enum match for ID: $keyId"),
      );

      dynamic value;
      switch (key.type) {
        case SettingType.string:
          value = reader.readString();
          break;
        case SettingType.boolean:
          value = reader.readBool();
          break;
        case SettingType.integer:
          value = reader.readInt();
          break;
        case SettingType.list:
          value = reader.readList();
          break;
      }

      resultDataMap[keyId] = value;
    }

    return resultDataMap;
  }

  @override
  void write(BinaryWriter writer, Map<dynamic, dynamic> obj) {
    writer.writeInt(obj.length);

    obj.forEach((rawKey, value) {
      final String keyId = rawKey is Enum ? rawKey.name : rawKey.toString();
      writer.writeString(keyId);

      final key = SettingKey.values.firstWhere(
        (k) => k.id == keyId,
        orElse: () => throw FormatException("Unknown SettingKey mapping name: $keyId"),
      );

      switch (key.type) {
        case SettingType.string:
          final strValue = value is String ? value : jsonEncode(value);
          writer.writeString(strValue);
          break;
        case SettingType.boolean:
          writer.writeBool(value as bool);
          break;
        case SettingType.integer:
          writer.writeInt(value as int);
          break;
        case SettingType.list:
          writer.writeList(value as List);
          break;
      }
    });
  }
}
