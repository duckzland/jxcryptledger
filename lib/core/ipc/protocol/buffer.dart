import 'dart:convert';
import 'dart:typed_data';
import 'packet.dart';

class CoreIpcBuffer {
  final BytesBuilder _builder = BytesBuilder();

  void add(Uint8List frame) => _builder.add(frame);
  int get length => _builder.length;
  void clear() => _builder.clear();

  CoreIpcPacket? parseNextAction() {
    if (_builder.length < 8) return null;

    final currentBytes = _builder.toBytes();
    final view = ByteData.sublistView(currentBytes);
    int offset = 0;

    if (currentBytes.length < offset + 4) return null;
    final reqId = view.getInt32(offset, Endian.big);
    offset += 4;

    if (currentBytes.length < offset + 1) return null;
    final op = view.getUint8(offset);
    offset += 1;

    if (currentBytes.length < offset + 2) return null;
    final actionLen = view.getInt16(offset, Endian.big);
    offset += 2;

    if (currentBytes.length < offset + actionLen) return null;
    final String action = utf8.decode(currentBytes.sublist(offset, offset + actionLen));
    offset += actionLen;

    if (currentBytes.length < offset + 2) return null;
    final keyLen = view.getInt16(offset, Endian.big);
    offset += 2;

    if (currentBytes.length < offset + keyLen) return null;
    final String key = utf8.decode(currentBytes.sublist(offset, offset + keyLen));
    offset += keyLen;

    if (currentBytes.length < offset + 4) return null;
    final valLen = view.getInt32(offset, Endian.big);
    offset += 4;

    final int expectedTotalFrameSize = offset + valLen;
    if (currentBytes.length < expectedTotalFrameSize) return null;

    final frameBytes = currentBytes.sublist(0, expectedTotalFrameSize);

    final remaining = _builder.takeBytes().sublist(expectedTotalFrameSize);
    _builder.clear();
    _builder.add(remaining);

    return CoreIpcPacket(reqId: reqId, op: op, action: action, key: key, payload: frameBytes.sublist(offset, expectedTotalFrameSize));
  }
}
