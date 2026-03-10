import 'package:hive_ce/hive_ce.dart';
import 'model.dart';

class TickersAdapter extends TypeAdapter<TickersModel> {
  @override
  final int typeId = 6;

  @override
  TickersModel read(BinaryReader reader) {
    return TickersModel(
      tid: reader.readString(),
      type: reader.readInt(),
      format: reader.readInt(),
      title: reader.readString(),
      order: reader.readInt(),
      value: reader.readString(),
      meta: Map<String, dynamic>.from(reader.readMap()),
    );
  }

  @override
  void write(BinaryWriter writer, TickersModel obj) {
    writer.writeString(obj.tid);
    writer.writeInt(obj.type);
    writer.writeInt(obj.format);
    writer.writeString(obj.title);
    writer.writeInt(obj.order);
    writer.writeString(obj.value);
    writer.writeMap(obj.meta);
  }
}
