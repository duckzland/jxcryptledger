// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_ce/hive_ce.dart';

class IpcWriter implements BinaryWriter {
  final BytesBuilder _builder = BytesBuilder();

  @override
  void writeByte(int byte) => _builder.add([byte]);

  @override
  void writeWord(int value) {
    final b = ByteData(2)..setUint16(0, value, Endian.big);
    _builder.add(b.buffer.asUint8List());
  }

  @override
  void writeInt32(int value) {
    final b = ByteData(4)..setInt32(0, value, Endian.big);
    _builder.add(b.buffer.asUint8List());
  }

  @override
  void writeUint32(int value) {
    final b = ByteData(4)..setUint32(0, value, Endian.big);
    _builder.add(b.buffer.asUint8List());
  }

  @override
  void writeInt(int value) {
    final b = ByteData(8)..setInt64(0, value, Endian.big);
    _builder.add(b.buffer.asUint8List());
  }

  @override
  void writeDouble(double value) {
    final b = ByteData(8)..setFloat64(0, value, Endian.big);
    _builder.add(b.buffer.asUint8List());
  }

  @override
  void writeBool(bool value) => writeByte(value ? 1 : 0);

  @override
  void writeString(String value, {bool writeByteCount = true, Converter<String, List<int>> encoder = BinaryWriter.utf8Encoder}) {
    final bytes = encoder.convert(value);
    if (writeByteCount) writeInt(bytes.length);
    _builder.add(bytes);
  }

  @override
  void writeByteList(List<int> bytes, {bool writeLength = true}) {
    if (writeLength) writeInt(bytes.length);
    _builder.add(bytes);
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
    } else {
      throw UnsupportedError(
        'Unsupported runtime type: ${value.runtimeType}. '
        'Pass an explicit context adapter variable instance to write().',
      );
    }
  }

  Uint8List toBytes() => _builder.toBytes();
}
