import 'dart:convert';
import 'dart:typed_data';

import '../../system/unlock/status.dart';
import '../database/adapters.dart';
import 'writer.dart';
import '../action.dart';

import 'reader.dart';

class IpcConverter {
  final IpcAdapters adapters;

  IpcConverter(this.adapters);

  Uint8List? toBytes(IpcAction op, String action, dynamic payload) {
    switch (op) {
      case IpcAction.put:
        final writer = IpcWriter();
        final adapter = adapters.get(action);
        adapter.write(writer, payload);
        return writer.toBytes();

      case IpcAction.replace:
      case IpcAction.multiPut:
        final writer = IpcWriter();
        final adapter = adapters.get(action);
        writer.writeInt(payload.length);
        for (final value in payload) {
          adapter.write(writer, value);
        }

        return writer.toBytes();

      case IpcAction.unlock:
        return payload;

      case IpcAction.notification:
        return utf8.encode(payload);

      default:
        return null;
    }
  }

  dynamic fromBytes(IpcAction op, String action, dynamic bytes) {
    switch (op) {
      case IpcAction.put:
        if (bytes.isNotEmpty) {
          return _bytesToModel(action, bytes);
        }

      case IpcAction.multiPut:
      case IpcAction.replace:
      case IpcAction.extract:
        if (bytes.isNotEmpty) {
          return _bytesToBatchModels(action, bytes);
        }

      case IpcAction.clear:
        if (bytes.isEmpty || bytes.length < 4) {
          return 0;
        }
        return ByteData.sublistView(bytes).getInt32(0, Endian.big);

      case IpcAction.unlock:
        if (bytes.isNotEmpty) {
          final status = SystemUnlockStatus.fromValue(bytes.first);
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
