import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../app/constants.dart';
import '../../../system/settings/model.dart';
import '../../../features/watchboard/tickers/service.dart';
import '../../ipc/database/migration.dart';
import '../log.dart';
import 'locator.dart';

class CoreRuntimeMigration extends IpcMigration {
  @override
  Future<void> migrateBeforeUnlock() async {
    // @deprecated Remove this in the next minor version release.
    if (isVersionLessThan(appVersion, "1.0.29.99")) {
      await _migrateOldFiles();
    }
  }

  @override
  Future<void> migrateAfterUnlock() async {
    if (isVersionLessThan(appVersion, "1.0.30.99")) {
      await _migrateSettingsBox();
      final TickersService tickersService = locator<TickersService>();
      final tickers = tickersService.extract();
      final exists = tickers.any((ticker) => ticker.tid == "market_cap");
      if (!exists) {
        await tickersService.clear();
        await tickersService.populate();
      }
    }
  }

  Future<void> _migrateOldFiles() async {
    Directory dir = await getApplicationDocumentsDirectory();
    String newHivePath = '${dir.path}/jxledger/live';

    String hivePath = dir.path;
    if (kDebugMode || kProfileMode) {
      hivePath = '${dir.path}/jxledger_dev';
      newHivePath = '${dir.path}/jxledger/dev';
    }

    final moveThis = await exists(hivePath);
    if (moveThis) {
      await migrateHiveFiles(hivePath, newHivePath, [
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
  }

  Future<void> _migrateSettingsBox() async {
    if (!Hive.isBoxOpen('settings_box')) {
      return;
    }

    final box = Hive.box<dynamic>('settings_box');
    final entries = Map<dynamic, dynamic>.from(box.toMap());

    for (final entry in entries.entries) {
      final dynamic rawValue = entry.value;
      if (rawValue is SettingsModel) {
        continue;
      }

      final String keyId = entry.key.toString();
      final dynamic legacyValue = rawValue is Map && rawValue.isNotEmpty ? rawValue[keyId] ?? rawValue.values.first : rawValue;
      final model = SettingsModel.fromLegacy(keyId, legacyValue);
      await box.put(keyId, model);
    }

    await box.flush();
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

  Future<bool> exists(String hivePath) async {
    if (kIsWeb) return false;

    final settingsFile = File('$hivePath/settings_box.hive');
    final transactionsFile = File('$hivePath/transactions_box.hive');

    return await settingsFile.exists() || await transactionsFile.exists();
  }
}
