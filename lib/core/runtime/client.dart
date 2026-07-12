import 'dart:io';
import 'dart:typed_data';

import '../../mixins/state.dart';
import '../../system/encryption/service.dart';
import '../../features/archives/controller.dart';
import '../../features/cryptos/controller.dart';
import '../../features/rates/controller.dart';
import '../../system/settings/controller.dart';
import '../../features/transactions/controller.dart';
import '../../features/watchboard/panels/controller.dart';
import '../../features/watchboard/tickers/controller.dart';
import '../../features/watchers/controller.dart';
import '../abstracts/runtime.dart';
import '../../ipc/action.dart';
import '../../ipc/client.dart';
import '../log.dart';
import '../mode.dart';
import 'locator.dart';

class CoreRuntimeClient extends CoreBaseRuntime with MixinsState {
  CoreRuntimeClient();

  final SettingsController _settingsController = locator<SettingsController>();
  final RatesController _ratesController = locator<RatesController>();
  final WatchersController _watchersController = locator<WatchersController>();
  final PanelsController _panelsController = locator<PanelsController>();
  final TickersController _tickersController = locator<TickersController>();
  final TransactionsController _transactionsController = locator<TransactionsController>();
  final CryptosController _cryptosController = locator<CryptosController>();
  final ArchivesController _archivesController = locator<ArchivesController>();

  @override
  Future<void> init() async {
    if (CoreMode.isInitialized) return;

    CoreMode.isServer = false;

    await setup();
    await bindLifecycle();
    await bindSignal();

    if (!isServerAvailable() && shouldSpawn()) {
      await spawnServer();
    }

    final serverReady = await waitForServer();
    if (!serverReady) {
      logln("Failed to spawn IPC server (Named Pipe: ${CoreMode.ipcPipeName} timeout)");
      fatalErrorNotice();
    }

    // Client strapping up
    ipcClient.pipeName = CoreMode.ipcPipeName;
    ipcClient.reconnecting = reconnect;
    ipcClient.exited = fatalErrorNotice;

    await ipcClient.start();

    logln("Connected to IPC server at Named Pipe: ${CoreMode.ipcPipeName}");

    CoreMode.isInitialized = true;
  }

  @override
  Future<void> shutdown() async {
    // Note: Had to wrap in try catch for each block to ensure we exit no matter what.

    try {
      if (CoreMode.isMain && CoreMode.isUnlocked) {
        await states.save();
      }
    } catch (_) {}

    try {
      if (!hasClient(exclude: pid) && isServerAvailable()) {
        logln("Shutting down server");
        await ipcClient.send(op: IpcAction.shutdown, action: "shutdown", key: pid);
      }
    } catch (_) {}

    try {
      broadcasterDispose();
    } catch (_) {}

    try {
      await ipcClient.dispose();
    } catch (_) {}
  }

  @override
  Future<bool> reconnect(IpcClient client) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (shouldSpawn() && !isServerAvailable()) {
      await spawnServer();
    }

    await waitForServer();

    await Future.delayed(const Duration(milliseconds: 50));

    if (isServerAvailable()) {
      await client.start();

      await Future.delayed(const Duration(milliseconds: 100));

      if (SystemEncryptionService.instance.isUnlocked()) {
        client.localKey = await SystemEncryptionService.instance.getRawKeyBytes();
        await client.send(op: IpcAction.unlock, action: "auth", key: "unlock", payload: client.localKey);
      }
      return true;
    }

    return false;
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

  Future<void> stopServices() async {
    _ratesController.dispose();
    _watchersController.dispose();
    _panelsController.dispose();
    _tickersController.dispose();
    _cryptosController.dispose();
    _archivesController.dispose();
    _transactionsController.dispose();
  }

  Future<bool> unlock(String password) async {
    final Uint8List keyBytes = await SystemEncryptionService.instance.loadPasswordKey(password);
    final Uint8List? sessionKey = await ipcClient.send(op: IpcAction.unlock, action: "auth", key: "unlocking", payload: keyBytes);

    if (sessionKey == null) {
      throw Exception("Failed to unlock vault due to marker mismatch");
    }

    ipcClient.localKey = keyBytes;
    ipcClient.sessionKey = sessionKey;

    await SystemEncryptionService.instance.loadKey(keyBytes);
    await _settingsController.init();
    final decrypted = await _settingsController.getDecryptedMarker();

    if (decrypted != 'initialized') {
      throw Exception("Failed to unlock vault due to marker mismatch (Expected 'initialized', got '$decrypted')");
    }

    logln("Password correct, vault unlocked");

    await checkDatabaseExists();
    await bootServices();

    CoreMode.isUnlocked = true;

    return true;
  }
}
