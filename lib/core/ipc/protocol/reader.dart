// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_ce/hive_ce.dart';

class CoreIpcReader implements BinaryReader {
  final ByteData _data;
  int _offset = 0;

  CoreIpcReader(Uint8List bytes) : _data = ByteData.sublistView(bytes);

  @override
  int get availableBytes => _data.lengthInBytes - _offset;

  @override
  int get usedBytes => _offset;

  @override
  void skip(int bytes) => _offset += bytes;

  @override
  int readByte() {
    final v = _data.getUint8(_offset);
    _offset += 1;
    return v;
  }

  @override
  Uint8List viewBytes(int bytes) {
    final slice = _data.buffer.asUint8List(_data.offsetInBytes + _offset, bytes);
    _offset += bytes;
    return slice;
  }

  @override
  Uint8List peekBytes(int bytes) {
    return _data.buffer.asUint8List(_data.offsetInBytes + _offset, bytes);
  }

  @override
  int readWord() {
    final v = _data.getUint16(_offset, Endian.big);
    _offset += 2;
    return v;
  }

  @override
  int readInt32() {
    final v = _data.getInt32(_offset, Endian.big);
    _offset += 4;
    return v;
  }

  @override
  int readUint32() {
    final v = _data.getUint32(_offset, Endian.big);
    _offset += 4;
    return v;
  }

  @override
  int readInt() {
    final v = _data.getInt64(_offset, Endian.big);
    _offset += 8;
    return v;
  }

  @override
  double readDouble() {
    final v = _data.getFloat64(_offset, Endian.big);
    _offset += 8;
    return v;
  }

  @override
  bool readBool() => readByte() == 1;

  @override
  String readString([int? byteCount, Converter<List<int>, String> decoder = BinaryReader.utf8Decoder]) {
    final len = byteCount ?? readInt();
    final bytes = _data.buffer.asUint8List(_data.offsetInBytes + _offset, len);
    _offset += len;
    return decoder.convert(bytes);
  }

  @override
  Uint8List readByteList([int? length]) {
    final len = length ?? readInt();
    final bytes = _data.buffer.asUint8List(_data.offsetInBytes + _offset, len);
    _offset += len;
    return bytes;
  }

  @override
  List<int> readIntList([int? length]) {
    final len = length ?? readInt();
    final list = <int>[];
    for (var i = 0; i < len; i++) {
      list.add(readInt());
    }
    return list;
  }

  @override
  List<double> readDoubleList([int? length]) {
    final len = length ?? readInt();
    final list = <double>[];
    for (var i = 0; i < len; i++) {
      list.add(readDouble());
    }
    return list;
  }

  @override
  List<bool> readBoolList([int? length]) {
    final len = length ?? readInt();
    final list = <bool>[];
    for (var i = 0; i < len; i++) {
      list.add(readBool());
    }
    return list;
  }

  @override
  List<String> readStringList([int? length, Converter<List<int>, String> decoder = BinaryReader.utf8Decoder]) {
    final len = length ?? readInt();
    final list = <String>[];
    for (var i = 0; i < len; i++) {
      list.add(readString(null, decoder));
    }
    return list;
  }

  @override
  List readList([int? length]) {
    final len = length ?? readInt();
    final list = [];
    for (var i = 0; i < len; i++) {
      list.add(read());
    }
    return list;
  }

  @override
  Map readMap([int? length]) {
    final len = length ?? readInt();
    final map = <dynamic, dynamic>{};
    for (var i = 0; i < len; i++) {
      final key = read();
      final value = read();
      map[key] = value;
    }
    return map;
  }

  @override
  dynamic read([int? typeId, TypeAdapter? adapter]) {
    if (adapter != null && typeId == null) {
      return adapter.read(this);
    }

    final int resolvedTypeId = typeId ?? readByte();

    if (adapter != null && resolvedTypeId == adapter.typeId) {
      return adapter.read(this);
    }

    switch (resolvedTypeId) {
      case 0:
        return null;
      case 1:
        return readBool();
      case 2:
        return readInt();
      case 3:
        return readDouble();
      case 4:
        return readString();
      case 5:
        return readByteList();
      case 6:
        return readList();
      case 7:
        return readMap();
      case 8:
        throw UnimplementedError('HiveList tracking not supported via raw buffers.');
      case 9:
        final dynamic k = read();
        final dynamic v = read();
        return MapEntry(k, v);
      default:
        if (adapter != null) {
          return adapter.read(this);
        }
        throw FormatException("Unknown TypeID: $resolvedTypeId");
    }
  }

  @override
  HiveList readHiveList([int? length]) {
    throw UnimplementedError('HiveList not supported.');
  }
}
