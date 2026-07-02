import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/router.dart';
import '../../../mixins/state.dart';
import '../../../features/archives/controller.dart';
import '../../../features/cryptos/controller.dart';
import '../../../system/encryption/service.dart';
import '../../../features/rates/controller.dart';
import '../../../system/settings/controller.dart';
import '../../../features/transactions/controller.dart';
import '../../../features/watchboard/panels/controller.dart';
import '../../../features/watchboard/tickers/controller.dart';
import '../../../features/watchers/controller.dart';
import '../../ipc/action.dart';
import '../../ipc/client.dart';
import '../../mixins/broadcaster.dart';
import '../../log.dart';
import '../../mode.dart';
import '../locator.dart';
import '../runtime.dart';

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

  Future<void> start() async {
    if (initialized) return;
    if (kIsWeb) return;

    ipcClient.onReconnect = (CoreIpcClient client) async {
      if (!CoreMode.isServer) {
        await Future.delayed(const Duration(milliseconds: 500));

        if (CoreRuntime.instance.shouldSpawn() && !CoreRuntime.instance.isServerAvailable()) {
          await CoreRuntime.instance.spawnServer();
        }
      }

      await CoreRuntime.instance.waitForServer();

      await Future.delayed(const Duration(milliseconds: 50));

      if (CoreRuntime.instance.isServerAvailable()) {
        await client.start();

        await Future.delayed(const Duration(milliseconds: 100));

        if (SystemEncryptionService.instance.isUnlocked()) {
          client.localKey = await SystemEncryptionService.instance.getRawKeyBytes();
          await client.send(op: CoreIpcAction.unlock, action: "auth", key: "unlock", payload: client.localKey);
        }
        return true;
      }

      return false;
    };

    ipcClient.onExit = () {
      AppRouter.router.go('/error');
    };

    ipcClient.pipeName = CoreMode.ipcPipeName;

    await ipcClient.start();

    isFirstRun = !await exists();

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
    final Uint8List keyBytes = await SystemEncryptionService.instance.loadPasswordKey(password);
    final Uint8List responseBytes = await ipcClient.send(op: CoreIpcAction.unlock, action: "auth", key: "unlocking", payload: keyBytes);
    final bool isUnlocked = responseBytes.isNotEmpty && responseBytes.first == 1;

    if (!isUnlocked) {
      throw Exception("Failed to unlock vault due to marker mismatch");
    }

    ipcClient.localKey = keyBytes;
    ipcClient.sessionKey = responseBytes.sublist(1);

    await SystemEncryptionService.instance.loadKey(keyBytes);
    await _settingsController.init();
    final decrypted = await _settingsController.getDecryptedMarker();

    if (decrypted != 'initialized') {
      throw Exception("Failed to unlock vault due to marker mismatch (Expected 'initialized', got '$decrypted')");
    }

    logln("Password correct, vault unlocked");

    isFirstRun = !await exists();

    await bootServices();

    return true;
  }
}
