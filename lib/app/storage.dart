import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../features/transactions/adapter.dart';
import '../features/settings/adapter.dart';

class AppStorage {
  AppStorage._();

  static final AppStorage instance = AppStorage._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Choose correct storage directory
    if (!kIsWeb) {
      Directory dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
    }

    // Register adapters
    Hive.registerAdapter(TransactionsAdapter());
    Hive.registerAdapter(SettingsModelAdapter());

    _initialized = true;
  }

  /// Open a Hive box safely
  Future<Box<T>> openBox<T>(String name) async {
    await init();
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return await Hive.openBox<T>(name);
  }

  /// Close all boxes
  Future<void> closeAll() async {
    await Hive.close();
    _initialized = false;
  }
}
