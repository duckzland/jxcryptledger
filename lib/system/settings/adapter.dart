import 'dart:convert';

import 'package:hive_ce/hive_ce.dart';
import 'keys.dart';
import 'model.dart';

class SettingsAdapter extends TypeAdapter<SettingsModel> {
  @override
  final int typeId = 8;

  @override
  SettingsModel read(BinaryReader reader) {
    final keyId = reader.readString();
    final typeIndex = reader.readInt();
    final type = SettingType.values[typeIndex];

    dynamic value;
    switch (type) {
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

    return SettingsModel(keyId: keyId, type: type, value: value);
  }

  @override
  void write(BinaryWriter writer, SettingsModel obj) {
    writer.writeString(obj.keyId);
    writer.writeInt(obj.type.index);

    switch (obj.type) {
      case SettingType.string:
        final strValue = obj.value is String ? obj.value : jsonEncode(obj.value);
        writer.writeString(strValue);
        break;
      case SettingType.boolean:
        writer.writeBool(obj.value as bool);
        break;
      case SettingType.integer:
        writer.writeInt(obj.value as int);
        break;
      case SettingType.list:
        writer.writeList(obj.value as List);
        break;
    }
  }
}
