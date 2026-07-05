import 'dart:convert';
import 'dart:typed_data';

import '../action.dart';

class IpcPacket {
  final int reqId;
  final int op;
  final String action;
  final String key;
  final Uint8List payload;

  IpcPacket({required this.reqId, required this.op, required this.action, required this.key, required this.payload});

  Uint8List toBytes() {
    final builder = BytesBuilder();
    builder.add(_int32(reqId));
    builder.add([op]);

    final actionBytes = utf8.encode(action);
    builder.add(_int16(actionBytes.length));
    builder.add(actionBytes);

    final keyBytes = utf8.encode(key);
    builder.add(_int16(keyBytes.length));
    builder.add(keyBytes);

    builder.add(_int32(payload.length));
    builder.add(payload);

    return builder.toBytes();
  }

  static IpcPacket fromBytes(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    int offset = 0;

    final reqId = byteData.getInt32(offset, Endian.big);
    offset += 4;

    final op = byteData.getUint8(offset);
    offset += 1;

    final actionLen = byteData.getInt16(offset, Endian.big);
    offset += 2;
    final action = utf8.decode(bytes.sublist(offset, offset + actionLen));
    offset += actionLen;

    final keyLen = byteData.getInt16(offset, Endian.big);
    offset += 2;
    final key = utf8.decode(bytes.sublist(offset, offset + keyLen));
    offset += keyLen;

    final valLen = byteData.getInt32(offset, Endian.big);
    offset += 4;
    final payload = bytes.sublist(offset, offset + valLen);

    return IpcPacket(reqId: reqId, op: op, action: action, key: key, payload: payload);
  }

  IpcAction get actionCode => IpcAction.fromCode(op);

  static Uint8List _int32(int v) => (ByteData(4)..setInt32(0, v, Endian.big)).buffer.asUint8List();
  static Uint8List _int16(int v) => (ByteData(2)..setInt16(0, v, Endian.big)).buffer.asUint8List();
}
