import 'dart:convert';
import 'dart:typed_data';
import 'packet.dart';

class IpcBuffer {
  Uint8List _bytes = Uint8List(1024);
  int _start = 0;
  int _end = 0;

  void add(Uint8List frame) {
    final remaining = _bytes.length - _end;
    if (remaining < frame.length) {
      final available = _bytes.length - (_end - _start);
      if (available >= frame.length) {
        _bytes.setRange(0, _end - _start, _bytes, _start);
        _end -= _start;
        _start = 0;
      } else {
        var capacity = _bytes.length;
        final required = _end - _start + frame.length;
        while (capacity < required) {
          capacity *= 2;
        }
        final grown = Uint8List(capacity);
        grown.setRange(0, _end - _start, _bytes, _start);
        _end -= _start;
        _start = 0;
        _bytes = grown;
      }
    }

    _bytes.setRange(_end, _end + frame.length, frame);
    _end += frame.length;
  }

  int get length => _end - _start;

  void clear() {
    _start = 0;
    _end = 0;
  }

  IpcPacket? parseNextAction() {
    if (length < 8) return null;

    final view = ByteData.sublistView(_bytes);
    var offset = _start;
    final end = _end;

    final reqId = view.getInt32(offset, Endian.big);
    offset += 4;

    final op = view.getUint8(offset);
    offset += 1;

    final actionLen = view.getInt16(offset, Endian.big);
    offset += 2;

    if (end < offset + actionLen) return null;
    final String action = utf8.decode(Uint8List.sublistView(_bytes, offset, offset + actionLen));
    offset += actionLen;

    if (end < offset + 2) return null;
    final keyLen = view.getInt16(offset, Endian.big);
    offset += 2;

    if (end < offset + keyLen) return null;
    final String key = utf8.decode(Uint8List.sublistView(_bytes, offset, offset + keyLen));
    offset += keyLen;

    if (end < offset + 4) return null;
    final valLen = view.getInt32(offset, Endian.big);
    offset += 4;

    final int expectedTotalFrameSize = offset + valLen;
    if (end < expectedTotalFrameSize) return null;

    final payload = Uint8List.fromList(Uint8List.sublistView(_bytes, offset, expectedTotalFrameSize));
    _start = expectedTotalFrameSize;
    if (_start == _end) {
      _start = 0;
      _end = 0;
    }

    return IpcPacket(reqId: reqId, op: op, action: action, key: key, payload: payload);
  }
}
