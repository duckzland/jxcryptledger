import 'dart:convert';
import 'dart:typed_data';

import '../abstracts/adapters.dart';
import '../status/op.dart';
import '../status/unlock.dart';

import 'writer.dart';
import 'reader.dart';

class IpcConverter {
  final IpcAdapters adapters;

  IpcConverter(this.adapters);

  Uint8List? toBytes(int op, String action, dynamic payload) {
    final opName = IpcStatusOp.getName(op);
    switch (opName) {
      case "put":
        final writer = IpcWriter();
        final adapter = adapters.get(action);
        adapter.write(writer, payload);
        return writer.toBytes();

      case "replace":
      case "multiPut":
        final writer = IpcWriter();
        final adapter = adapters.get(action);
        writer.writeInt(payload.length);
        for (final value in payload) {
          adapter.write(writer, value);
        }

        return writer.toBytes();

      case "unlock":
        return payload;

      default:
        if (payload is String) return utf8.encode(payload);
        return null;
    }
  }

  dynamic fromBytes(int op, String action, dynamic bytes) {
    final opName = IpcStatusOp.getName(op);
    switch (opName) {
      case "put":
        if (bytes.isNotEmpty) {
          return _bytesToModel(action, bytes);
        }

      case "multiPut":
      case "replace":
      case "extract":
        if (bytes.isNotEmpty) {
          return _bytesToBatchModels(action, bytes);
        }

      case "clear":
        if (bytes.isEmpty || bytes.length < 4) {
          return 0;
        }
        return ByteData.sublistView(bytes).getInt32(0, Endian.big);

      case "unlock":
        if (bytes.isNotEmpty) {
          final status = IpcStatusUnlock.fromValue(bytes.first);
          if (status.isUnlocked()) {
            return bytes.sublist(1);
          }
        }

        return null;

      default:
        return null;
    }
  }

  dynamic _bytesToModel(String action, dynamic bytes) {
    final adapter = adapters.get(action);
    final reader = IpcReader(bytes);
    return reader.read(null, adapter);
  }

  dynamic _bytesToBatchModels(String action, dynamic bytes) {
    List<dynamic> results = [];
    final reader = IpcReader(bytes);
    final int count = reader.readInt();
    final adapter = adapters.get(action);

    for (var i = 0; i < count; i++) {
      final dynamic decodedItem = reader.read(null, adapter);
      results.add(decodedItem);
    }
    return results;
  }
}
