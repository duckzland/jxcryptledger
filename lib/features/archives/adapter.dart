import 'package:hive_ce/hive_ce.dart';
import 'model.dart';

class ArchivesAdapter extends TypeAdapter<ArchivesModel> {
  @override
  final int typeId = 7;

  @override
  ArchivesModel read(BinaryReader reader) {
    return ArchivesModel(
      aid: reader.readString(),
      type: reader.readInt(),
      data: reader.readString(),
      timestamp: reader.readInt(),
      meta: Map<String, dynamic>.from(reader.readMap()),
    );
  }

  @override
  void write(BinaryWriter writer, ArchivesModel obj) {
    writer.writeString(obj.aid);
    writer.writeInt(obj.type);
    writer.writeString(obj.data);
    writer.writeInt(obj.timestamp);
    writer.writeMap(obj.meta);
  }
}
