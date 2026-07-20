import 'package:flutter/foundation.dart';

import '../../system/unlock/status.dart';
import 'adapters.dart';
import 'boxes.dart';
import 'migration.dart';

class IpcDatabase {
  final IpcBoxes boxes;
  final IpcAdapters adapters;
  final IpcMigration migration;

  IpcDatabase(this.boxes, this.adapters, this.migration);

  bool initialized = false;
  SystemUnlockStatus? unlocked;
  bool isFirstRun = false;
  String path = "";

  Future<void> init() async {
    if (initialized) return;
    if (kIsWeb) return;

    adapters.register();

    migration.migrateBeforeUnlock();

    boxes.hivePath = path;
    boxes.init();

    initialized = true;
  }

  Future<SystemUnlockStatus> unlock(Uint8List keyBytes) async {
    if (unlocked == null || !unlocked!.isUnlocked()) {
      final status = await boxes.unlock(keyBytes);
      if (status.isUnlocked()) {
        migration.migrateAfterUnlock();
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
}
