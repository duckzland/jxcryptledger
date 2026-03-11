import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../core/log.dart';
import '../features/cryptos/adapter.dart';
import '../features/cryptos/model.dart';
import '../features/rates/adapter.dart';
import '../features/rates/model.dart';
import '../features/watchboard/panels/adapter.dart';
import '../features/watchboard/panels/model.dart';
import '../features/watchboard/tickers/adapter.dart';
import '../features/watchboard/tickers/model.dart';
import '../features/transactions/adapter.dart';
import '../features/transactions/model.dart';
import '../features/watchers/adapter.dart';
import '../features/watchers/model.dart';

class AppStorage {
  AppStorage._();
  static final AppStorage instance = AppStorage._();

  bool _initialized = false;
  String? _hivePath;

  Future<void> init() async {
    if (_initialized) return;

    // Not supporting web!
    if (kIsWeb) return;

    Directory dir = await getApplicationDocumentsDirectory();

    String newHivePath = '${dir.path}/jxledger/live';

    // Set as old dir first for checking and migrating
    _hivePath = dir.path;

    if (kDebugMode) {
      _hivePath = '${dir.path}/jxledger_dev';
      newHivePath = '${dir.path}/jxledger/dev';
    }

    final moveThis = await exists();
    if (moveThis) {
      await migrateHiveFiles(_hivePath!, newHivePath, [
        'rates_box',
        'cryptos_box',
        'settings_box',
        'watchers_box',
        'transactions_box',
        'panels_box',
        'tickers_box',
      ]);
    }

    // Switch to new directory
    _hivePath = newHivePath;

    if (!await Directory(_hivePath!).exists()) {
      await Directory(_hivePath!).create(recursive: true);
    }

    logln("Initializing Hive at $newHivePath");
    Hive.init(_hivePath!);

    Hive.registerAdapter<TransactionsModel>(TransactionsAdapter());
    Hive.registerAdapter<CryptosModel>(CryptosAdapter());
    Hive.registerAdapter<RatesModel>(RatesAdapter());
    Hive.registerAdapter<WatchersModel>(WatchersAdapter());
    Hive.registerAdapter<PanelsModel>(PanelsAdapter());
    Hive.registerAdapter<TickersModel>(TickersAdapter());

    _initialized = true;
  }

  Future<Box<T>> openBox<T>(String name, {HiveCipher? encryptionCipher, bool crashRecovery = true}) async {
    await init();

    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }

    return await Hive.openBox<T>(name, encryptionCipher: encryptionCipher, crashRecovery: crashRecovery);
  }

  Future<Box<T>> openOrRebuildBox<T>(String name, {HiveCipher? encryptionCipher, bool crashRecovery = true}) async {
    await init();

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

  Future<void> migrateHiveFiles(String oldDirPath, String newDirPath, List<String> boxNames) async {
    await Hive.close();

    final oldDir = Directory(oldDirPath);
    final newDir = Directory(newDirPath);

    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
    }

    for (String boxName in boxNames) {
      final extensions = ['.hive', '.lock'];

      for (String ext in extensions) {
        final fileName = '$boxName$ext';
        final oldFile = File(p.join(oldDir.path, fileName));
        final newFile = File(p.join(newDir.path, fileName));

        if (await oldFile.exists()) {
          try {
            await oldFile.rename(newFile.path);

            logln('Moved $fileName to new folder.');
          } catch (e) {
            await oldFile.copy(newFile.path);
            await oldFile.delete();

            logln('Copied and deleted $fileName (rename failed).');
          }
        }
      }
    }
  }

  Future<void> closeAll() async {
    await Hive.close();
    _initialized = false;
  }

  Future<bool> exists() async {
    if (kIsWeb) return false;

    if (_hivePath == null) {
      return false;
    }

    final settingsFile = File('$_hivePath/settings_box.hive');
    final transactionsFile = File('$_hivePath/transactions_box.hive');

    return await settingsFile.exists() || await transactionsFile.exists();
  }
}
