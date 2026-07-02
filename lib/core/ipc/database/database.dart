import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../app/constants.dart';
import '../../../features/archives/adapter.dart';
import '../../../features/archives/model.dart';
import '../../../features/cryptos/adapter.dart';
import '../../../features/cryptos/model.dart';
import '../../../system/encryption/service.dart';
import '../../../features/rates/adapter.dart';
import '../../../features/rates/model.dart';
import '../../../system/settings/adapter.dart';
import '../../../system/settings/model.dart';
import '../../../features/transactions/adapter.dart';
import '../../../features/transactions/model.dart';
import '../../../features/watchboard/panels/adapter.dart';
import '../../../features/watchboard/panels/model.dart';
import '../../../features/watchboard/tickers/adapter.dart';
import '../../../features/watchboard/tickers/model.dart';
import '../../../features/watchers/adapter.dart';
import '../../../features/watchers/model.dart';
import '../../runtime/locker.dart';
import '../../log.dart';
import '../registry.dart';

class CoreIpcDatabase {
  bool initialized = false;
  bool unlocked = false;
  bool isFirstRun = false;
  String? hivePath;

  Future<void> init() async {
    if (initialized) return;

    // Not supporting web!
    if (kIsWeb) return;

    Directory dir = await getApplicationDocumentsDirectory();
    String newHivePath = '${dir.path}/jxledger/live';

    hivePath = dir.path;
    if (kDebugMode || kProfileMode) {
      hivePath = '${dir.path}/jxledger_dev';
      newHivePath = '${dir.path}/jxledger/dev';
    }

    final moveThis = await exists();
    if (moveThis) {
      await migrateHiveFiles(hivePath!, newHivePath, [
        'rates_box',
        'cryptos_box',
        'settings_box',
        'watchers_box',
        'transactions_box',
        'panels_box',
        'tickers_box',
        'archives_box',
      ]);
    }

    // Switch to new directory
    hivePath = newHivePath;

    if (!await Directory(hivePath!).exists()) {
      await Directory(hivePath!).create(recursive: true);
    }

    logln("Initializing Hive at $newHivePath");
    CoreLocker.lockAndCleanHive(hivePath!);
    Hive.init(hivePath!);

    Hive.registerAdapter<TransactionsModel>(TransactionsAdapter());
    Hive.registerAdapter<CryptosModel>(CryptosAdapter());
    Hive.registerAdapter<RatesModel>(RatesAdapter());
    Hive.registerAdapter<WatchersModel>(WatchersAdapter());
    Hive.registerAdapter<PanelsModel>(PanelsAdapter());
    Hive.registerAdapter<TickersModel>(TickersAdapter());
    Hive.registerAdapter<ArchivesModel>(ArchivesAdapter());
    Hive.registerAdapter<SettingsModel>(SettingsAdapter());

    initialized = true;
  }

  Future<int> unlock(Uint8List keyBytes) async {
    isFirstRun = !await exists();

    if (!unlocked) {
      try {
        HiveAesCipher cipher;
        await SystemEncryptionService.instance.loadKey(keyBytes);
        cipher = HiveAesCipher(keyBytes);

        final settingsBox = await openBox<dynamic>('settings_box', encryptionCipher: cipher, crashRecovery: false);
        await _migrateSettingsBoxEntries(settingsBox);

        await openBox<TransactionsModel>('transactions_box', encryptionCipher: cipher, crashRecovery: false);

        await openBox<PanelsModel>('panels_box', encryptionCipher: cipher, crashRecovery: false);

        await openBox<ArchivesModel>('archives_box', encryptionCipher: cipher, crashRecovery: false);

        await openOrRebuildBox<CryptosModel>('cryptos_box', encryptionCipher: null, crashRecovery: false);

        await openOrRebuildBox<RatesModel>('rates_box', encryptionCipher: null, crashRecovery: false);

        await openOrRebuildBox<WatchersModel>('watchers_box', encryptionCipher: null, crashRecovery: false);

        await openOrRebuildBox<TickersModel>('tickers_box', encryptionCipher: null, crashRecovery: false);

        unlocked = true;
      } catch (e) {
        logln("Failed to decrypt boxes (wrong password): ${e.toString()}");
        return unlockError;
      }
    }

    if (isFirstRun) {
      return unlockFirstTime;
    }

    return unlockSuccess;
  }

  Future<Box<T>?> openBox<T>(String name, {HiveCipher? encryptionCipher, bool crashRecovery = true}) async {
    await init();

    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }

    final box = await Hive.openBox<T>(name, encryptionCipher: encryptionCipher, crashRecovery: crashRecovery);
    CoreIpcRegistry.registerBox(name, box);

    return box;
  }

  Future<Box<T>?> openOrRebuildBox<T>(String name, {HiveCipher? encryptionCipher, bool crashRecovery = true}) async {
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
    initialized = false;
  }

  Future<void> _migrateSettingsBoxEntries(Box<dynamic>? box) async {
    if (box == null) {
      return;
    }

    final entries = Map<dynamic, dynamic>.from(box.toMap());
    for (final entry in entries.entries) {
      final dynamic rawValue = entry.value;
      if (rawValue is SettingsModel) {
        continue;
      }

      final String keyId = entry.key.toString();
      final dynamic legacyValue = rawValue is Map && rawValue.isNotEmpty ? rawValue[keyId] ?? rawValue.values.first : rawValue;
      final SettingsModel model = SettingsModel.fromLegacy(keyId, legacyValue);
      await box.put(keyId, model);
    }

    await box.flush();
  }
}
