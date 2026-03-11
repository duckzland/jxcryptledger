import 'package:hive_ce/hive_ce.dart';
import 'model.dart';

class PanelsAdapter extends TypeAdapter<PanelsModel> {
  @override
  final int typeId = 5;

  @override
  PanelsModel read(BinaryReader reader) {
    return PanelsModel(
      tid: reader.readString(),
      srAmount: reader.readDouble(),
      srId: reader.readInt(),
      rrId: reader.readInt(),
      digit: reader.readInt(),
      rate: reader.readDouble(),
      order: reader.readInt(),
      meta: Map<String, dynamic>.from(reader.readMap()),
    );
  }

  @override
  void write(BinaryWriter writer, PanelsModel obj) {
    writer.writeString(obj.tid);
    writer.writeDouble(obj.srAmount);
    writer.writeInt(obj.srId);
    writer.writeInt(obj.rrId);
    writer.writeInt(obj.digit);
    writer.writeDouble(obj.rate ?? 0.0);
    writer.writeInt(obj.order ?? 0);
    writer.writeMap(obj.meta);
  }
}
