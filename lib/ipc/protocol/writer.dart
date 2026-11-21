// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:decimal/decimal.dart';
import 'package:hive_ce/hive_ce.dart';

class IpcWriter implements BinaryWriter {
  Uint8List _buffer = Uint8List(1024);
  late ByteData _view = ByteData.view(_buffer.buffer);
  int _length = 0;

  void _ensureCapacity(int additional) {
    final required = _length + additional;
    if (required <= _buffer.length) return;

    var capacity = _buffer.length;
    while (capacity < required) {
      capacity *= 2;
    }

    final buffer = Uint8List(capacity)..setRange(0, _length, _buffer);
    _buffer = buffer;
    _view = ByteData.view(buffer.buffer);
  }

  void _append(List<int> bytes) {
    _ensureCapacity(bytes.length);
    _buffer.setRange(_length, _length + bytes.length, bytes);
    _length += bytes.length;
  }

  @override
  void writeByte(int byte) {
    _ensureCapacity(1);
    _view.setUint8(_length++, byte);
  }

  @override
  void writeWord(int value) {
    _ensureCapacity(2);
    _view.setUint16(_length, value, Endian.big);
    _length += 2;
  }

  @override
  void writeInt32(int value) {
    _ensureCapacity(4);
    _view.setInt32(_length, value, Endian.big);
    _length += 4;
  }

  @override
  void writeUint32(int value) {
    _ensureCapacity(4);
    _view.setUint32(_length, value, Endian.big);
    _length += 4;
  }

  @override
  void writeInt(int value) {
    _ensureCapacity(8);
    _view.setInt64(_length, value, Endian.big);
    _length += 8;
  }

  @override
  void writeDouble(double value) {
    _ensureCapacity(8);
    _view.setFloat64(_length, value, Endian.big);
    _length += 8;
  }

  @override
  void writeBool(bool value) => writeByte(value ? 1 : 0);

  @override
  void writeString(String value, {bool writeByteCount = true, Converter<String, List<int>> encoder = BinaryWriter.utf8Encoder}) {
    final bytes = encoder.convert(value);
    if (writeByteCount) writeInt(bytes.length);
    _append(bytes);
  }

  @override
  void writeByteList(List<int> bytes, {bool writeLength = true}) {
    if (writeLength) writeInt(bytes.length);
    _append(bytes);
  }

  @override
  void writeIntList(List<int> list, {bool writeLength = true}) {
    if (writeLength) writeInt(list.length);
    for (final v in list) {
      writeInt(v);
    }
  }

  @override
  void writeDoubleList(List<double> list, {bool writeLength = true}) {
    if (writeLength) writeInt(list.length);
    for (final v in list) {
      writeDouble(v);
    }
  }

  @override
  void writeBoolList(List<bool> list, {bool writeLength = true}) {
    if (writeLength) writeInt(list.length);
    for (final v in list) {
      writeBool(v);
    }
  }

  @override
  void writeStringList(List<String> list, {bool writeLength = true, Converter<String, List<int>> encoder = BinaryWriter.utf8Encoder}) {
    if (writeLength) writeInt(list.length);
    for (final s in list) {
      writeString(s, encoder: encoder);
    }
  }

  @override
  void writeList(List list, {bool writeLength = true}) {
    if (writeLength) writeInt(list.length);
    for (final v in list) {
      write(v);
    }
  }

  @override
  void writeMap(Map map, {bool writeLength = true}) {
    if (writeLength) writeInt(map.length);
    map.forEach((key, value) {
      write(key);
      write(value);
    });
  }

  @override
  void writeHiveList(HiveList list, {bool writeLength = true}) {
    if (writeLength) writeInt(list.length);
    for (final v in list) {
      write(v);
    }
  }

  @override
  void write<T>(T value, {bool withTypeId = true, TypeAdapter? adapter}) {
    if (value == null) {
      if (withTypeId) writeByte(0); // Type ID 0: Null
      return;
    }

    if (adapter != null) {
      adapter.write(this, value);
      return;
    }

    if (value is bool) {
      if (withTypeId) writeByte(1);
      writeBool(value);
    } else if (value is int) {
      if (withTypeId) writeByte(2);
      writeInt(value);
    } else if (value is double) {
      if (withTypeId) writeByte(3);
      writeDouble(value);
    } else if (value is String) {
      if (withTypeId) writeByte(4);
      writeString(value);
    } else if (value is Uint8List) {
      if (withTypeId) writeByte(5);
      writeByteList(value);
    } else if (value is List) {
      if (withTypeId) writeByte(6);
      writeList(value);
    } else if (value is Map) {
      if (withTypeId) writeByte(7);
      writeMap(value);
    } else if (value is HiveList) {
      if (withTypeId) writeByte(8);
      writeHiveList(value);
    } else if (value is MapEntry) {
      if (withTypeId) writeByte(9);
      write(value.key);
      write(value.value);
    } else if (value is Decimal) {
      if (withTypeId) writeByte(10);
      writeString(value.toString());
    } else {
      throw UnsupportedError(
        'Unsupported runtime type: ${value.runtimeType}. '
        'Pass an explicit context adapter variable instance to write().',
      );
    }
  }

  Uint8List toBytes() {
    final bytes = Uint8List.fromList(_buffer.sublist(0, _length));
    _length = 0;
    return bytes;
  }
}
