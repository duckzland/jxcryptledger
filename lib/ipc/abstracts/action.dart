import 'dart:typed_data';
import 'database.dart';

import '../status/op.dart';

abstract class IpcAction {
  final IpcDatabase database;

  const IpcAction({required this.database});

  Future<void> init() async {
    await database.init();
  }

  Future<void> dispose() async {
    await database.dispose();
  }

  Future<Uint8List> process(int op, String action, String key, Uint8List payload) async {
    final opName = IpcStatusOp.getName(op);
    final dynamic nativeHiveKey = int.tryParse(key) ?? key;

    switch (opName) {
      case "put":
        await database.addBytes(action, nativeHiveKey, payload);
        break;

      case "delete":
        await database.delete(action, nativeHiveKey);
        break;

      case "clear":
        await database.clear(action);
        break;

      case "flush":
        await database.flush(action);
        break;

      case "extract":
        return database.extractBytes(action);

      case "multiPut":
        await database.insertBytes(action, payload);
        break;

      case "replace":
        await database.clear(action);
        await database.insertBytes(action, payload);
        break;

      default:
        break;
    }

    return Uint8List(0);
  }
}
