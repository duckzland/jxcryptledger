import 'dart:convert';
import 'dart:typed_data';

import 'packet.dart';

class CoreIpcBuffer {
  final BytesBuilder _builder = BytesBuilder();

  void add(Uint8List frame) => _builder.add(frame);
  int get length => _builder.length;

  void clear() {
    _builder.clear();
  }

  CoreIpcPacket? parseNextAction() {
    if (_builder.length < 8) return null;

    final Uint8List currentBytes = _builder.toBytes();
    final headerReader = ByteData.sublistView(currentBytes);
    int offset = 0;

    final reqId = headerReader.getInt32(offset, Endian.big);
    offset += 4;

    final op = headerReader.getUint8(offset);
    offset += 1;

    if (currentBytes.length < offset + 2) return null;
    final boxLen = headerReader.getInt16(offset, Endian.big);
    offset += 2;

    if (currentBytes.length < offset + boxLen + 2) return null;
    final boxName = utf8.decode(currentBytes.sublist(offset, offset + boxLen));
    offset += boxLen;

    final keyLen = headerReader.getInt16(offset, Endian.big);
    offset += 2;

    if (currentBytes.length < offset + keyLen + 4) return null;
    final String rawKeyStr = utf8.decode(currentBytes.sublist(offset, offset + keyLen));
    offset += keyLen;

    final valLen = headerReader.getInt32(offset, Endian.big);
    offset += 4;

    final int expectedTotalFrameSize = offset + valLen;
    if (currentBytes.length < expectedTotalFrameSize) return null;

    final valueBytes = currentBytes.sublist(offset, expectedTotalFrameSize);

    final remaining = _builder.takeBytes().sublist(expectedTotalFrameSize);
    _builder.clear();
    _builder.add(remaining);

    return CoreIpcPacket(reqId: reqId, op: op, boxName: boxName, key: rawKeyStr, valueBytes: valueBytes);
  }
}
