import 'dart:convert';
import 'dart:typed_data';

class CoreIpcPacket {
  final int reqId;
  final int op;
  final String boxName;
  final String key;
  final Uint8List valueBytes;

  CoreIpcPacket({required this.reqId, required this.op, required this.boxName, required this.key, required this.valueBytes});

  Uint8List toBytes() {
    final builder = BytesBuilder();
    builder.add(_int32(reqId));
    builder.add([op]);

    final boxBytes = utf8.encode(boxName);
    builder.add(_int16(boxBytes.length));
    builder.add(boxBytes);

    final keyBytes = utf8.encode(key);
    builder.add(_int16(keyBytes.length));
    builder.add(keyBytes);

    builder.add(_int32(valueBytes.length));
    builder.add(valueBytes);

    return builder.toBytes();
  }

  static Uint8List _int32(int v) => (ByteData(4)..setInt32(0, v, Endian.big)).buffer.asUint8List();
  static Uint8List _int16(int v) => (ByteData(2)..setInt16(0, v, Endian.big)).buffer.asUint8List();
}
