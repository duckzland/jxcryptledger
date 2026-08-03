import 'package:decimal/decimal.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../core/extensions/decimals.dart';
import '../../core/mode.dart';
import 'model.dart';

class TransactionsAdapter extends TypeAdapter<TransactionsModel> {
  @override
  final int typeId = 1;

  @override
  TransactionsModel read(BinaryReader reader) {
    final String tid;
    final String rid;
    final String pid;
    final Decimal srAmount;
    final int srId;
    final Decimal rrAmount;
    final int rrId;
    final Decimal balance;
    final int status;
    final bool closable;
    final int timestamp;
    final Map<String, dynamic> meta;

    switch (CoreMode.dbVersion) {
      case "v1.1.0":
        tid = reader.readString();
        rid = reader.readString();
        pid = reader.readString();
        srAmount = Decimal.parse(reader.readDouble().toString());
        srId = reader.readInt();
        rrAmount = Decimal.parse(reader.readDouble().toString());
        rrId = reader.readInt();
        balance = Decimal.parse(reader.readDouble().toString());
        status = reader.readInt();
        closable = reader.readBool();
        timestamp = reader.readInt();
        meta = Map<String, dynamic>.from(reader.readMap());
        break;

      default:
        tid = reader.readString();
        rid = reader.readString();
        pid = reader.readString();
        srAmount = reader.readDecimal();
        srId = reader.readInt();
        rrAmount = reader.readDecimal();
        rrId = reader.readInt();
        balance = reader.readDecimal();
        status = reader.readInt();
        closable = reader.readBool();
        timestamp = reader.readInt();
        meta = Map<String, dynamic>.from(reader.readMap());
        break;
    }

    return TransactionsModel(
      tid: tid,
      rid: rid,
      pid: pid,
      srAmount: srAmount,
      srId: srId,
      rrAmount: rrAmount,
      rrId: rrId,
      balance: balance,
      status: status,
      closable: closable,
      timestamp: timestamp,
      meta: meta,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionsModel obj) {
    writer.writeString(obj.tid);
    writer.writeString(obj.rid);
    writer.writeString(obj.pid);
    writer.writeDecimal(obj.srAmount);
    writer.writeInt(obj.srId);
    writer.writeDecimal(obj.rrAmount);
    writer.writeInt(obj.rrId);
    writer.writeDecimal(obj.balance);
    writer.writeInt(obj.status);
    writer.writeBool(obj.closable);
    writer.writeInt(obj.timestamp);
    writer.writeMap(obj.meta);
  }
}
