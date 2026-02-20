import 'package:hive_ce/hive_ce.dart';
import 'model.dart';

class CryptosAdapter extends TypeAdapter<CryptosModel> {
  @override
  final int typeId = 2;

  @override
  CryptosModel read(BinaryReader reader) {
    return CryptosModel(
      id: reader.readInt(),
      name: reader.readString(),
      symbol: reader.readString(),
      status: reader.readInt(),
      active: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, CryptosModel obj) {
    writer.writeInt(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.symbol);
    writer.writeInt(obj.status);
    writer.writeInt(obj.active);
  }
}
