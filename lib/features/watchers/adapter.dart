import 'package:decimal/decimal.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../core/extensions/decimals.dart';
import '../../core/mode.dart';
import 'model.dart';

class WatchersAdapter extends TypeAdapter<WatchersModel> {
  @override
  final int typeId = 4;

  @override
  WatchersModel read(BinaryReader reader) {
    final String wid;
    final int srId;
    final int rrId;
    final Decimal rates;
    final int sent;
    final int operator;
    final int limit;
    final int duration;
    final String message;
    final int timestamp;
    final Map<String, dynamic> meta;

    switch (CoreMode.dbVersion) {
      case "v1.1.0":
        wid = reader.readString();
        srId = reader.readInt();
        rrId = reader.readInt();
        rates = Decimal.parse(reader.readDouble().toString());
        sent = reader.readInt();
        operator = reader.readInt();
        limit = reader.readInt();
        duration = reader.readInt();
        message = reader.readString();
        timestamp = reader.readInt();
        meta = Map<String, dynamic>.from(reader.readMap());
        break;

      default:
        wid = reader.readString();
        srId = reader.readInt();
        rrId = reader.readInt();
        rates = reader.readDecimal();
        sent = reader.readInt();
        operator = reader.readInt();
        limit = reader.readInt();
        duration = reader.readInt();
        message = reader.readString();
        timestamp = reader.readInt();
        meta = Map<String, dynamic>.from(reader.readMap());
        break;
    }

    return WatchersModel(
      wid: wid,
      srId: srId,
      rrId: rrId,
      rates: rates,
      sent: sent,
      operator: operator,
      limit: limit,
      duration: duration,
      message: message,
      timestamp: timestamp,
      meta: meta,
    );
  }

  @override
  void write(BinaryWriter writer, WatchersModel obj) {
    writer.writeString(obj.wid);
    writer.writeInt(obj.srId);
    writer.writeInt(obj.rrId);
    writer.writeDecimal(obj.rates);
    writer.writeInt(obj.sent);
    writer.writeInt(obj.operator);
    writer.writeInt(obj.limit);
    writer.writeInt(obj.duration);
    writer.writeString(obj.message);
    writer.writeInt(obj.timestamp);
    writer.writeMap(obj.meta);
  }
}
