import 'package:hive_ce/hive_ce.dart';
import 'package:decimal/decimal.dart';

import 'model.dart';

class RatesAdapter extends TypeAdapter<RatesModel> {
  @override
  final int typeId = 3; // choose a unique ID

  @override
  RatesModel read(BinaryReader reader) {
    return RatesModel(
      sourceSymbol: reader.readString(),
      sourceId: reader.readInt(),
      sourceAmount: Decimal.parse(reader.readString()),
      targetSymbol: reader.readString(),
      targetId: reader.readInt(),
      targetAmount: Decimal.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, RatesModel obj) {
    writer.writeString(obj.sourceSymbol);
    writer.writeInt(obj.sourceId);
    writer.writeString(obj.sourceAmount.toString());
    writer.writeString(obj.targetSymbol);
    writer.writeInt(obj.targetId);
    writer.writeString(obj.targetAmount.toString());
  }
}
