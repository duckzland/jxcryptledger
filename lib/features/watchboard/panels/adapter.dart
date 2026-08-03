import 'package:decimal/decimal.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../../core/extensions/decimals.dart';
import '../../../core/mode.dart';
import 'model.dart';

class PanelsAdapter extends TypeAdapter<PanelsModel> {
  @override
  final int typeId = 5;

  @override
  PanelsModel read(BinaryReader reader) {
    final String tid;
    final Decimal srAmount;
    final int srId;
    final int rrId;
    final int digit;
    final Decimal rate;
    final int order;
    final Map<String, dynamic> meta;

    switch (CoreMode.dbVersion) {
      case "v1.1.0":
        tid = reader.readString();
        srAmount = Decimal.parse(reader.readDouble().toString());
        srId = reader.readInt();
        rrId = reader.readInt();
        digit = reader.readInt();
        rate = Decimal.parse(reader.readDouble().toString());
        order = reader.readInt();
        meta = Map<String, dynamic>.from(reader.readMap());
        break;

      default:
        tid = reader.readString();
        srAmount = reader.readDecimal();
        srId = reader.readInt();
        rrId = reader.readInt();
        digit = reader.readInt();
        rate = reader.readDecimal();
        order = reader.readInt();
        meta = Map<String, dynamic>.from(reader.readMap());
        break;
    }

    return PanelsModel(tid: tid, srAmount: srAmount, srId: srId, rrId: rrId, digit: digit, rate: rate, order: order, meta: meta);
  }

  @override
  void write(BinaryWriter writer, PanelsModel obj) {
    writer.writeString(obj.tid);
    writer.writeDecimal(obj.srAmount);
    writer.writeInt(obj.srId);
    writer.writeInt(obj.rrId);
    writer.writeInt(obj.digit);
    writer.writeDecimal(obj.rate);
    writer.writeInt(obj.order ?? 0);
    writer.writeMap(obj.meta);
  }
}
