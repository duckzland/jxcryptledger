import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../core/log.dart';
import '../features/cryptos/adapter.dart';
import '../features/cryptos/model.dart';
import '../features/rates/adapter.dart';
import '../features/rates/model.dart';
import '../features/transactions/adapter.dart';
import '../features/transactions/model.dart';
import '../features/watchers/adapter.dart';
import '../features/watchers/model.dart';

class AppStorage {
  AppStorage._();
  static final AppStorage instance = AppStorage._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (!kIsWeb) {
      Directory dir = await getApplicationDocumentsDirectory();
      String hivePath = dir.path;

      // Force dev to use different folder
      if (kDebugMode) {
        hivePath = '${dir.path}/jxledger_dev';
      }

      logln("Initializing Hive at $hivePath");
      Hive.init(hivePath);
    }

    Hive.registerAdapter<TransactionsModel>(TransactionsAdapter());
    Hive.registerAdapter<CryptosModel>(CryptosAdapter());
    Hive.registerAdapter<RatesModel>(RatesAdapter());
    Hive.registerAdapter<WatchersModel>(WatchersAdapter());

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

  Future<void> closeAll() async {
    await Hive.close();
    _initialized = false;
  }

  Future<bool> exists() async {
    if (kIsWeb) return false;

    final dir = await getApplicationDocumentsDirectory();

    final settingsFile = File('${dir.path}/settings_box.hive');
    final transactionsFile = File('${dir.path}/transactions_box.hive');

    return await settingsFile.exists() || await transactionsFile.exists();
  }
}
