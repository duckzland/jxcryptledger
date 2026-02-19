import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../features/transactions/adapter.dart';
import '../features/transactions/model.dart';

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

    // Register ONLY the adapter for complex models
    Hive.registerAdapter<TransactionsModel>(TransactionsAdapter());

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

    // Ensure this await is direct. Do not wrap in a
    // try-catch here unless you 'rethrow'!
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

  /// Check if the database files already exist on disk
  Future<bool> exists() async {
    if (kIsWeb) return false;

    final dir = await getApplicationDocumentsDirectory();
    // Use join or raw path to check for the .hive files
    final settingsFile = File('${dir.path}/settings_box.hive');
    final transactionsFile = File('${dir.path}/transactions_box.hive');

    // Return true if EITHER exists (usually they are created together)
    return await settingsFile.exists() || await transactionsFile.exists();
  }
}
