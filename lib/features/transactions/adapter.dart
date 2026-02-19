import 'package:hive/hive.dart';
import 'model.dart';

class TransactionsAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 1;

  @override
  TransactionModel read(BinaryReader reader) {
    return TransactionModel(
      tid: reader.readString(),
      rid: reader.readString(),
      pid: reader.readString(),
      srAmount: reader.readDouble(),
      srId: reader.readInt(),
      rrAmount: reader.readDouble(),
      rrId: reader.readInt(),
      timestamp: reader.readInt(),
      meta: Map<String, dynamic>.from(reader.readMap()),
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer.writeString(obj.tid);
    writer.writeString(obj.rid);
    writer.writeString(obj.pid);
    writer.writeDouble(obj.srAmount);
    writer.writeInt(obj.srId);
    writer.writeDouble(obj.rrAmount);
    writer.writeInt(obj.rrId);
    writer.writeInt(obj.timestamp);
    writer.writeMap(obj.meta);
  }
}
