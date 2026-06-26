import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/worker.dart';
import '../../mixins/state.dart';
import '../../features/archives/controller.dart';
import '../../features/cryptos/controller.dart';
import '../../features/encryption/service.dart';
import '../../features/rates/controller.dart';
import '../../features/settings/controller.dart';
import '../../features/transactions/controller.dart';
import '../../features/watchboard/panels/controller.dart';
import '../../features/watchboard/tickers/controller.dart';
import '../../features/watchers/controller.dart';
import '../mixins/broadcaster.dart';
import '../locator.dart';
import '../log.dart';

class CoreBootstrapClient with MixinsState, CoreMixinsBroadcaster {
  bool initialized = false;
  bool unlocked = false;
  bool isFirstRun = false;

  final SettingsController _settingsController = locator<SettingsController>();
  final RatesController _ratesController = locator<RatesController>();
  final WatchersController _watchersController = locator<WatchersController>();
  final PanelsController _panelsController = locator<PanelsController>();
  final TickersController _tickersController = locator<TickersController>();
  final TransactionsController _transactionsController = locator<TransactionsController>();
  final CryptosController _cryptosController = locator<CryptosController>();
  final ArchivesController _archivesController = locator<ArchivesController>();

  final AppWorker appWorker = locator<AppWorker>();

  Future<void> start() async {
    if (initialized) return;
    if (kIsWeb) return;

    await ipcClient.start();
    await ipcClient.register();

    initialized = true;
  }

  Future<void> bootServices() async {
    await _ratesController.init();
    await _watchersController.init();
    await _panelsController.init();
    await _tickersController.init();
    await _cryptosController.init();
    await _archivesController.init();
    await _transactionsController.init();

    states.init();
  }

  Future<bool> exists() async {
    if (kIsWeb) return false;

    Directory dir = await getApplicationDocumentsDirectory();
    String hivePath = '${dir.path}/jxledger/live';

    if (kDebugMode || kProfileMode) {
      hivePath = '${dir.path}/jxledger/dev';
    }

    final settingsFile = File('$hivePath/settings_box.hive');
    final transactionsFile = File('$hivePath/transactions_box.hive');

    return await settingsFile.exists() || await transactionsFile.exists();
  }

  Future<bool> unlock(String password) async {
    final pwBytes = utf8.encode(password);

    final Uint8List responseBytes = await ipcClient.sendAction(op: 0x07, box: "auth", key: "unlocking", value: pwBytes);
    final bool isUnlocked = responseBytes.isNotEmpty && responseBytes.first == 1;

    if (!isUnlocked) {
      throw Exception("Failed to unlock vault due to marker mismatch");
    }

    await EncryptionService.instance.loadPasswordKey(password);
    await _settingsController.init();
    final decrypted = await _settingsController.getDecryptedMarker();

    if (decrypted != 'initialized') {
      throw Exception("Failed to unlock vault due to marker mismatch (Expected 'initialized', got '$decrypted')");
    }

    logln("Password correct, vault unlocked");

    await bootServices();

    return true;
  }
}
