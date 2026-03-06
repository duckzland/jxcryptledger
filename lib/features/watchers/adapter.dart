import 'package:hive_ce/hive_ce.dart';
import 'model.dart';

class WatchersAdapter extends TypeAdapter<WatchersModel> {
  @override
  final int typeId = 4;

  @override
  WatchersModel read(BinaryReader reader) {
    return WatchersModel(
      wid: reader.readString(),
      srId: reader.readInt(),
      rrId: reader.readInt(),
      rates: reader.readDouble(),
      sent: reader.readInt(),
      limit: reader.readInt(),
      duration: reader.readInt(),
      message: reader.readString(),
      timestamp: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, WatchersModel obj) {
    writer.writeString(obj.wid);
    writer.writeInt(obj.srId);
    writer.writeInt(obj.rrId);
    writer.writeDouble(obj.rates);
    writer.writeInt(obj.sent);
    writer.writeInt(obj.limit);
    writer.writeInt(obj.duration);
    writer.writeString(obj.message);
    writer.writeInt(obj.timestamp);
  }
}
