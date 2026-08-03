import 'package:hive_ce/hive_ce.dart';

import '../../core/extensions/decimals.dart';
import 'model.dart';

class RatesAdapter extends TypeAdapter<RatesModel> {
  @override
  final int typeId = 3;

  @override
  RatesModel read(BinaryReader reader) {
    return RatesModel(
      sourceSymbol: reader.readString(),
      sourceId: reader.readInt(),
      sourceAmount: reader.readDecimal(),
      targetSymbol: reader.readString(),
      targetId: reader.readInt(),
      targetAmount: reader.readDecimal(),
      timestamp: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, RatesModel obj) {
    writer.writeString(obj.sourceSymbol);
    writer.writeInt(obj.sourceId);
    writer.writeDecimal(obj.sourceAmount);
    writer.writeString(obj.targetSymbol);
    writer.writeInt(obj.targetId);
    writer.writeDecimal(obj.targetAmount);
    writer.writeInt(obj.timestamp);
  }
}
