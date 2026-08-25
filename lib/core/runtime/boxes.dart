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
import '../../../features/watchboard/markets/model.dart';
import '../../../features/watchers/model.dart';
import '../../../system/unlock/status.dart';
import '../../system/settings/keys.dart';
import '../../system/settings/model.dart';
import '../log.dart';
import '../mode.dart';

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
    HiveAesCipher cipher;

    Box? settingsBox;

    try {
      await SystemEncryptionService.instance.loadKey(keyBytes);
      cipher = HiveAesCipher(keyBytes);
    } catch (e) {
      logln("Failed to generate cipher for unlocking: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    try {
      settingsBox = await openBox<SettingsModel>('settings_box', encryptionCipher: cipher, crashRecovery: false);
    } catch (e) {
      logln("Failed to open settings_box: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    try {
      if (settingsBox != null) {
        SettingsModel? setting = settingsBox.get(SettingKey.migrateVersion.id);
        CoreMode.dbVersion = (setting?.value ?? SettingKey.migrateVersion.defaultValue) as String;
        logln("Using database version ${CoreMode.dbVersion}", "BOXES");
      }
    } catch (e) {
      logln("Failed to set database version: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    try {
      await openBox<TransactionsModel>('transactions_box', encryptionCipher: cipher, crashRecovery: false);
    } catch (e) {
      logln("Failed to open transactions_box: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    try {
      await openBox<PanelsModel>('panels_box', encryptionCipher: cipher, crashRecovery: false);
    } catch (e) {
      logln("Failed to open panels_box: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    try {
      await openBox<ArchivesModel>('archives_box', encryptionCipher: cipher, crashRecovery: false);
    } catch (e) {
      logln("Failed to open archives_box: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    try {
      await openOrRebuildBox<CryptosModel>('cryptos_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to open cryptos_box: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    try {
      await openOrRebuildBox<RatesModel>('rates_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to open rates_box: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    try {
      await openOrRebuildBox<WatchersModel>('watchers_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to open watchers_box: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    try {
      await openOrRebuildBox<TickersModel>('tickers_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to open tickers_box: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    try {
      await openOrRebuildBox<MarketsModel>('markets_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to open markets_box: $e", "BOXES");
      return SystemUnlockStatus.error;
    }

    return (isFirstRun) ? SystemUnlockStatus.firstTime : SystemUnlockStatus.success;
  }
}
