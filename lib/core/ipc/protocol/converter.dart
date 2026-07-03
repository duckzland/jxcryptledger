import 'dart:convert';
import 'dart:typed_data';

import '../database/adapters.dart';
import '../protocol/writer.dart';
import '../action.dart';
import 'reader.dart';

class CoreIpcConverter {
  final CoreIpcAdapters adapters;

  CoreIpcConverter(this.adapters);

  Uint8List? toBytes(CoreIpcAction op, String action, dynamic payload) {
    switch (op) {
      case CoreIpcAction.put:
        final writer = CoreIpcWriter();
        final adapter = adapters.get(action);
        adapter.write(writer, payload);
        return writer.toBytes();

      case CoreIpcAction.replace:
      case CoreIpcAction.multiPut:
        final writer = CoreIpcWriter();
        final adapter = adapters.get(action);
        writer.writeInt(payload.length);
        for (final value in payload) {
          adapter.write(writer, value);
        }

        return writer.toBytes();

      case CoreIpcAction.unlock:
        return payload;

      case CoreIpcAction.notification:
        return utf8.encode(payload);

      default:
        return null;
    }
  }

  dynamic fromSenderBytes(CoreIpcAction op, String action, dynamic bytes) {
    switch (op) {
      case CoreIpcAction.extract:
        List<dynamic> results = [];
        final reader = CoreIpcReader(bytes);
        final int count = reader.readInt();
        final adapter = adapters.get(action);

        for (var i = 0; i < count; i++) {
          final dynamic decodedItem = reader.read(null, adapter);
          results.add(decodedItem);
        }
        return results;

      case CoreIpcAction.clear:
        return ByteData.sublistView(bytes).getInt32(0, Endian.big);

      case CoreIpcAction.unlock:
        return bytes.isNotEmpty && bytes.first == 1 ? bytes.sublist(1) : null;
      default:
        return null;
    }
  }

  dynamic fromBroadcasterBytes(CoreIpcAction op, String action, dynamic bytes) {
    switch (op) {
      case CoreIpcAction.put:
        final adapter = adapters.get(action);
        final reader = CoreIpcReader(bytes);
        return reader.read(null, adapter);

      case CoreIpcAction.multiPut:
      case CoreIpcAction.replace:
        List<dynamic> results = [];
        final reader = CoreIpcReader(bytes);
        final int count = reader.readInt();
        final adapter = adapters.get(action);

        for (var i = 0; i < count; i++) {
          final dynamic decodedItem = reader.read(null, adapter);
          results.add(decodedItem);
        }
        return results;

      default:
        return null;
    }
  }
}
