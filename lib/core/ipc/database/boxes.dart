import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';

import '../../log.dart';
import '../../runtime/locker.dart';

class CoreIpcBoxes {
  final Map<String, Box> boxes = {};
  String? hivePath;

  Future<void> init() async {
    Directory dir = await getApplicationDocumentsDirectory();
    hivePath = '${dir.path}/jxledger/live';
    if (kDebugMode || kProfileMode) {
      hivePath = '${dir.path}/jxledger/dev';
    }

    if (!await Directory(hivePath!).exists()) {
      await Directory(hivePath!).create(recursive: true);
    }

    logln("Initializing Hive at $hivePath");
    CoreLocker.lockAndCleanHive(hivePath!);
    Hive.init(hivePath!);
  }

  void register(String boxName, Box box) {
    boxes[boxName] = box;
  }

  List<String> getKeys() {
    return boxes.keys.toList();
  }

  Box get(String boxName) {
    final box = boxes[boxName];
    if (box == null) {
      throw StateError("No box instance registered for '$boxName'");
    }
    return box;
  }

  Future<Box<T>?> openBox<T>(String name, {HiveCipher? encryptionCipher, bool crashRecovery = true}) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }

    final box = await Hive.openBox<T>(name, encryptionCipher: encryptionCipher, crashRecovery: crashRecovery);
    register(name, box);

    return box;
  }

  Future<Box<T>?> openOrRebuildBox<T>(String name, {HiveCipher? encryptionCipher, bool crashRecovery = true}) async {
    Box<T>? box;
    try {
      box = await openBox<T>(name, encryptionCipher: encryptionCipher, crashRecovery: crashRecovery);
      return box;
    } catch (e) {
      logln("Failed to open $name: ${e.toString()}");

      try {
        if (box != null && box.isOpen) {
          await box.close();
        } else if (Hive.isBoxOpen(name)) {
          await Hive.box<T>(name).close();
        }

        await Future.delayed(const Duration(milliseconds: 100));

        await Hive.deleteBoxFromDisk(name);
        box = await openBox<T>(name, encryptionCipher: encryptionCipher, crashRecovery: crashRecovery);
        logln("Rebuild box $name completed");
        return box;
      } catch (rebuildError) {
        logln("Rebuild failed for $name: ${rebuildError.toString()}");
        rethrow;
      }
    }
  }

  Future<bool> exists() async {
    if (kIsWeb) return false;

    if (hivePath == null) {
      return false;
    }

    final settingsFile = File('$hivePath/settings_box.hive');
    final transactionsFile = File('$hivePath/transactions_box.hive');

    return await settingsFile.exists() || await transactionsFile.exists();
  }

  Future<void> dispose() async {
    await Hive.close();
  }
}
