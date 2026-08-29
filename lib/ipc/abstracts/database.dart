import 'package:flutter/foundation.dart';

import '../status/unlock.dart';
import '../protocol/reader.dart';
import '../protocol/writer.dart';

import 'adapters.dart';
import 'boxes.dart';
import 'migration.dart';
import 'model.dart';

abstract class IpcDatabase {
  final IpcBoxes boxes;
  final IpcAdapters adapters;
  final IpcMigration migration;
  final String path;

  IpcDatabase(this.boxes, this.adapters, this.migration, this.path);

  bool initialized = false;
  bool isFirstRun = false;

  IpcStatusUnlock? unlocked;

  Future<void> init() async {
    if (initialized) return;
    if (kIsWeb) return;

    adapters.register();

    migration.migrateBeforeUnlock();

    boxes.hivePath = path;
    boxes.init();

    initialized = true;
  }

  Future<IpcStatusUnlock> unlock(Uint8List keyBytes) async {
    if (unlocked == null || !unlocked!.isUnlocked()) {
      final status = await boxes.unlock(keyBytes);
      if (status.isUnlocked()) {
        await migration.migrateAfterUnlock();
      }

      unlocked = status;
      return status;
    }

    return unlocked!;
  }

  Future<void> dispose() async {
    await boxes.dispose();
    initialized = false;
  }

  Future<void> delete(String boxName, dynamic key) async {
    final box = boxes.get(boxName);
    await box.delete(key);
    await box.flush();
  }

  Future<void> put(String boxName, dynamic key, dynamic value) async {
    final box = boxes.get(boxName);
    await box.put(key, value);
    await box.flush();
  }

  Future<void> clear(String boxName) async {
    final box = boxes.get(boxName);
    await box.clear();
    await box.flush();
  }

  Future<void> flush(String boxName) async {
    final box = boxes.get(boxName);
    await box.flush();
  }

  Iterable<dynamic> keys(String boxName) {
    final box = boxes.get(boxName);
    return box.keys;
  }

  dynamic get(String boxName, dynamic id) {
    final box = boxes.get(boxName);
    return box.get(id);
  }

  Uint8List extractBytes(String boxName) {
    final writer = IpcWriter();
    final adapter = adapters.get(boxName);
    final keys = this.keys(boxName);
    final int realCount = keys.length;
    writer.writeInt(realCount);

    for (var key in keys) {
      final dynamic value = get(boxName, key);

      if (value is Uint8List) {
        writer.writeByteList(value, writeLength: false);
      } else if (value != null) {
        adapter.write(writer, value);
      }
    }

    return writer.toBytes();
  }

  Future<void> addBytes(String boxName, dynamic id, Uint8List payload) async {
    final reader = IpcReader(payload);
    final adapter = adapters.get(boxName);
    final dynamic decoded = adapter.read(reader);
    final dynamic finalValue = decoded is MapEntry ? decoded.value : decoded;
    await put(boxName, id, finalValue);
  }

  Future<void> insertBytes(String boxName, Uint8List payload) async {
    final batchReader = IpcReader(payload);
    final int totalItems = batchReader.readInt();
    final adapter = adapters.get(boxName);

    for (int i = 0; i < totalItems; i++) {
      dynamic nativeHiveKey;
      dynamic finalValue;

      finalValue = adapter.read(batchReader);
      nativeHiveKey = (finalValue is IpcModel) ? finalValue.uuid : i;
      await put(boxName, nativeHiveKey, finalValue);
    }
  }
}
