import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxledger/ipc/database/boxes.dart';

import '../../../features/archives/model.dart';
import '../../../features/cryptos/model.dart';
import '../../../system/encryption/service.dart';
import '../../../features/rates/model.dart';
import '../../../features/transactions/model.dart';
import '../../../features/watchboard/panels/model.dart';
import '../../../features/watchboard/tickers/model.dart';
import '../../../features/watchers/model.dart';
import '../../../system/unlock/status.dart';
import '../log.dart';

class CoreRuntimeBoxes extends IpcBoxes {
  @override
  Future<bool> exists() async {
    if (kIsWeb) return false;

    if (hivePath == null) {
      return false;
    }

    final settingsFile = File('$hivePath/settings_box.hive');
    final transactionsFile = File('$hivePath/transactions_box.hive');

    return await settingsFile.exists() || await transactionsFile.exists();
  }

  @override
  Future<SystemUnlockStatus> unlock(Uint8List keyBytes) async {
    final isFirstRun = !await exists();

    try {
      HiveAesCipher cipher;
      await SystemEncryptionService.instance.loadKey(keyBytes);
      cipher = HiveAesCipher(keyBytes);

      await openBox<dynamic>('settings_box', encryptionCipher: cipher, crashRecovery: false);

      await openBox<TransactionsModel>('transactions_box', encryptionCipher: cipher, crashRecovery: false);

      await openBox<PanelsModel>('panels_box', encryptionCipher: cipher, crashRecovery: false);

      await openBox<ArchivesModel>('archives_box', encryptionCipher: cipher, crashRecovery: false);

      await openOrRebuildBox<CryptosModel>('cryptos_box', encryptionCipher: null, crashRecovery: false);

      await openOrRebuildBox<RatesModel>('rates_box', encryptionCipher: null, crashRecovery: false);

      await openOrRebuildBox<WatchersModel>('watchers_box', encryptionCipher: null, crashRecovery: false);

      await openOrRebuildBox<TickersModel>('tickers_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to decrypt boxes (wrong password): ${e.toString()}");
      return SystemUnlockStatus.error;
    }

    return (isFirstRun) ? SystemUnlockStatus.firstTime : SystemUnlockStatus.success;
  }
}
