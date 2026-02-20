import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../features/transactions/adapter.dart';
import '../features/transactions/model.dart';

import '../features/cryptos/adapter.dart';
import '../features/cryptos/model.dart';

import '../features/rates/adapter.dart';
import '../features/rates/model.dart';

class AppStorage {
  AppStorage._();
  static final AppStorage instance = AppStorage._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (!kIsWeb) {
      Directory dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
    }

    Hive.registerAdapter<TransactionsModel>(TransactionsAdapter());
    Hive.registerAdapter<CryptosModel>(CryptosAdapter());
    Hive.registerAdapter<RatesModel>(RatesAdapter());

    _initialized = true;
  }

  Future<Box<T>> openBox<T>(
    String name, {
    HiveCipher? encryptionCipher,
    bool crashRecovery = true,
  }) async {
    await init();

    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }

    return await Hive.openBox<T>(
      name,
      encryptionCipher: encryptionCipher,
      crashRecovery: crashRecovery,
    );
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
