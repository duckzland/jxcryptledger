import 'package:hive_ce/hive_ce.dart';
import 'model.dart';

class TransactionsAdapter extends TypeAdapter<TransactionsModel> {
  @override
  final int typeId = 1;

  @override
  TransactionsModel read(BinaryReader reader) {
    return TransactionsModel(
      tid: reader.readString(),
      rid: reader.readString(),
      pid: reader.readString(),
      srAmount: reader.readDouble(),
      srId: reader.readInt(),
      rrAmount: reader.readDouble(),
      rrId: reader.readInt(),
      balance: reader.readDouble(),
      status: reader.readInt(),
      timestamp: reader.readInt(),
      meta: Map<String, dynamic>.from(reader.readMap()),
    );
  }

  @override
  void write(BinaryWriter writer, TransactionsModel obj) {
    writer.writeString(obj.tid);
    writer.writeString(obj.rid);
    writer.writeString(obj.pid);
    writer.writeDouble(obj.srAmount);
    writer.writeInt(obj.srId);
    writer.writeDouble(obj.rrAmount);
    writer.writeInt(obj.rrId);
    writer.writeDouble(obj.balance);
    writer.writeInt(obj.status);
    writer.writeInt(obj.timestamp);
    writer.writeMap(obj.meta);
  }
}
