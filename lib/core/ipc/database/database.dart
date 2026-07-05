import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../../features/archives/model.dart';
import '../../../features/cryptos/model.dart';
import '../../../system/encryption/service.dart';
import '../../../features/rates/model.dart';
import '../../../features/transactions/model.dart';
import '../../../features/watchboard/panels/model.dart';
import '../../../features/watchboard/tickers/model.dart';
import '../../../features/watchers/model.dart';
import '../../log.dart';
import '../../../system/unlock/status.dart';
import 'adapters.dart';
import 'boxes.dart';
import 'migration.dart';

class CoreIpcDatabase {
  final CoreIpcBoxes boxes;
  final CoreIpcAdapters adapters;
  final CoreIpcMigration migration;

  CoreIpcDatabase(this.boxes, this.adapters, this.migration);

  bool initialized = false;
  bool unlocked = false;
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
    isFirstRun = !await boxes.exists();

    if (!unlocked) {
      try {
        HiveAesCipher cipher;
        await SystemEncryptionService.instance.loadKey(keyBytes);
        cipher = HiveAesCipher(keyBytes);

        await boxes.openBox<dynamic>('settings_box', encryptionCipher: cipher, crashRecovery: false);

        await boxes.openBox<TransactionsModel>('transactions_box', encryptionCipher: cipher, crashRecovery: false);

        await boxes.openBox<PanelsModel>('panels_box', encryptionCipher: cipher, crashRecovery: false);

        await boxes.openBox<ArchivesModel>('archives_box', encryptionCipher: cipher, crashRecovery: false);

        await boxes.openOrRebuildBox<CryptosModel>('cryptos_box', encryptionCipher: null, crashRecovery: false);

        await boxes.openOrRebuildBox<RatesModel>('rates_box', encryptionCipher: null, crashRecovery: false);

        await boxes.openOrRebuildBox<WatchersModel>('watchers_box', encryptionCipher: null, crashRecovery: false);

        await boxes.openOrRebuildBox<TickersModel>('tickers_box', encryptionCipher: null, crashRecovery: false);

        migration.migrateAfterUnlock();

        unlocked = true;
      } catch (e) {
        logln("Failed to decrypt boxes (wrong password): ${e.toString()}");
        return SystemUnlockStatus.error;
      }
    }

    if (isFirstRun) {
      return SystemUnlockStatus.firstTime;
    }

    return SystemUnlockStatus.success;
  }

  Future<void> dispose() async {
    await boxes.dispose();
    initialized = false;
  }

  Future<void> delete(String boxName, dynamic key) async {
    final box = boxes.get(boxName);
    await box.delete(key);
  }

  Future<void> put(String boxName, dynamic key, dynamic value) async {
    final box = boxes.get(boxName);
    await box.put(key, value);
  }

  Future<void> clear(String boxName) async {
    final box = boxes.get(boxName);
    await box.clear();
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
