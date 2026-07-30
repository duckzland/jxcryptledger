import 'package:hive_ce/hive_ce.dart';
import 'model.dart';

class MarketsAdapter extends TypeAdapter<MarketsModel> {
  @override
  final int typeId = 9;

  @override
  MarketsModel read(BinaryReader reader) {
    return MarketsModel(
      tid: reader.readString(),
      name: reader.readString(),
      symbol: reader.readString(),
      rank: reader.readInt(),
      isInfinite: reader.readBool(),
      totalSupply: _readNullableDouble(reader),
      maxSupply: _readNullableDouble(reader),
      price: _readNullableDouble(reader),
      volume24h: _readNullableDouble(reader),
      volumeChange24h: _readNullableDouble(reader),
      percent1h: _readNullableDouble(reader),
      percent24h: _readNullableDouble(reader),
      percent7d: _readNullableDouble(reader),
      percent30d: _readNullableDouble(reader),
      percent60d: _readNullableDouble(reader),
      percent90d: _readNullableDouble(reader),
      marketCap: _readNullableDouble(reader),
      dominance: _readNullableDouble(reader),
      meta: Map<String, dynamic>.from(reader.readMap()),
    );
  }

  @override
  void write(BinaryWriter writer, MarketsModel obj) {
    writer.writeString(obj.tid);
    writer.writeString(obj.name);
    writer.writeString(obj.symbol);
    writer.writeInt(obj.rank);
    writer.writeBool(obj.isInfinite);
    _writeNullableDouble(writer, obj.totalSupply);
    _writeNullableDouble(writer, obj.maxSupply);
    _writeNullableDouble(writer, obj.price);
    _writeNullableDouble(writer, obj.volume24h);
    _writeNullableDouble(writer, obj.volumeChange24h);
    _writeNullableDouble(writer, obj.percent1h);
    _writeNullableDouble(writer, obj.percent24h);
    _writeNullableDouble(writer, obj.percent7d);
    _writeNullableDouble(writer, obj.percent30d);
    _writeNullableDouble(writer, obj.percent60d);
    _writeNullableDouble(writer, obj.percent90d);
    _writeNullableDouble(writer, obj.marketCap);
    _writeNullableDouble(writer, obj.dominance);
    writer.writeMap(obj.meta);
  }

  // Helpers for nullable double
  double? _readNullableDouble(BinaryReader reader) {
    final hasValue = reader.readBool();
    return hasValue ? reader.readDouble() : null;
  }

  void _writeNullableDouble(BinaryWriter writer, double? value) {
    if (value == null) {
      writer.writeBool(false);
    } else {
      writer.writeBool(true);
      writer.writeDouble(value);
    }
  }
}
