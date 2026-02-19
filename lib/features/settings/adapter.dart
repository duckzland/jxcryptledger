import 'package:hive/hive.dart';
import 'model.dart';

class SettingsModelAdapter extends TypeAdapter<SettingsModel> {
  @override
  final int typeId = 2;

  @override
  SettingsModel read(BinaryReader reader) {
    return SettingsModel(meta: Map<String, dynamic>.from(reader.readMap()));
  }

  @override
  void write(BinaryWriter writer, SettingsModel obj) {
    writer.writeMap(obj.meta);
  }
}
