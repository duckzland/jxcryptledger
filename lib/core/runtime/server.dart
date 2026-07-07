import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../features/archives/service.dart';
import '../../features/cryptos/service.dart';
import '../../features/notification/service.dart';
import '../../features/rates/service.dart';
import '../../system/encryption/service.dart';
import '../../system/settings/keys.dart';
import '../../system/settings/service.dart';
import '../../features/transactions/service.dart';
import '../../features/watchboard/panels/service.dart';
import '../../features/watchboard/tickers/service.dart';
import '../../features/watchers/service.dart';
import '../../system/unlock/status.dart';
import '../../ipc/action.dart';
import '../../ipc/client.dart';
import '../../ipc/database/adapters.dart';
import '../../ipc/database/database.dart';
import '../abstracts/runtime.dart';
import '../log.dart';
import '../mode.dart';
import '../worker.dart';

import 'boxes.dart';
import 'locator.dart';
import 'migration.dart';

class CoreRuntimeServer extends CoreBaseRuntime {
  CoreRuntimeServer();

  final SettingsService _settingsService = locator<SettingsService>();
  final RatesService _ratesService = locator<RatesService>();
  final WatchersService _watchersService = locator<WatchersService>();
  final PanelsService _panelsService = locator<PanelsService>();
  final TickersService _tickersService = locator<TickersService>();
  final TransactionsService _transactionsService = locator<TransactionsService>();
  final CryptosService _cryptosService = locator<CryptosService>();
  final ArchivesService _archivesService = locator<ArchivesService>();
  final NotificationService _notificationService = locator<NotificationService>();

  final CoreWorker appWorker = locator<CoreWorker>();

  Timer? _serverWatchdog;

  @override
  Future<void> init() async {
    if (CoreMode.isInitialized) return;

    CoreMode.isServer = true;

    await setup();
    await bindLifecycle();
    await bindSignal();

    cleanSocketFile();

    ipcServer.pipeName = CoreMode.ipcPipeName;
    ipcServer.database = IpcDatabase(CoreRuntimeBoxes(), locator<IpcAdapters>(), CoreRuntimeMigration());
    ipcServer.unlocker = unlock;
    ipcServer.shutdown = shutdown;
    ipcServer.disconnected = shutdownWhenNoClient;
    ipcServer.hasClient = hasClient;
    ipcServer.database.path = CoreMode.path;

    await ipcServer.database.init();
    await ipcServer.start();

    final serverReady = await waitForServer();
    if (!serverReady) {
      logln("Exiting due to failed to detect IPC server: ${CoreMode.ipcPipeName}");
      shutdown();
      return;
    }

    logln("IPC server running via Named Pipe: ${CoreMode.ipcPipeName}");

    // Client strapping up
    ipcClient.pipeName = CoreMode.ipcPipeName;
    ipcClient.reconnecting = reconnect;

    await ipcClient.start();

    logln("Connected to IPC server at Named Pipe: ${CoreMode.ipcPipeName}");

    _serverWatchdog = Timer.periodic(const Duration(seconds: 5), (_) async {
      shutdownWhenNoClient();
    });

    CoreMode.isInitialized = true;
  }

  @override
  Future<void> shutdown() async {
    // Note: Had to wrap in try catch for each block to ensure we exit no matter what.
    try {
      _serverWatchdog?.cancel();
      _serverWatchdog = null;
    } catch (_) {}

    try {
      lifecycleListener.dispose();
    } catch (_) {}

    try {
      broadcasterDispose();
    } catch (_) {}

    try {
      await stopServices();
    } catch (_) {}

    try {
      await ipcClient.dispose();
    } catch (_) {}
    try {
      await ipcServer.dispose();
    } catch (_) {}

    try {
      await stdout.close();
    } catch (_) {}

    try {
      await stderr.close();
    } catch (_) {}

    exit(0);
  }

  @override
  Future<bool> reconnect(IpcClient client) async {
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
    await _settingsService.init();
    await _notificationService.init();
    await _ratesService.init();
    await _watchersService.init();
    await _panelsService.init();
    await _tickersService.init();
    await _cryptosService.init();
    await _archivesService.init();
    await _transactionsService.init();

    appWorker.start();
  }

  Future<void> stopServices() async {
    await _settingsService.dispose();
    await _notificationService.dispose();
    await _ratesService.dispose();
    await _watchersService.dispose();
    await _panelsService.dispose();
    await _tickersService.dispose();
    await _cryptosService.dispose();
    await _archivesService.dispose();
    await _transactionsService.dispose();

    appWorker.stop();
  }

  void shutdownWhenNoClient() {
    if (!hasClient()) {
      logln("Exiting due to server has no more connected client");
      shutdown();
    }
  }

  Future<SystemUnlockStatus> unlock(Uint8List keyBytes) async {
    final SystemUnlockStatus state = await ipcServer.database.unlock(keyBytes);

    if (!state.isUnlocked()) {
      return state;
    }

    if (!state.isFirstRun()) {
      ipcClient.sessionKey ??= ipcServer.sessionKey;
      await bootServices();
      CoreMode.isFirstRun = false;
    }

    if (state.isFirstRun()) {
      CoreMode.isFirstRun = true;
      try {
        logln("First run detected, initializing vault");
        ipcClient.sessionKey ??= ipcServer.sessionKey;
        await _settingsService.save(SettingKey.vaultInitialized, "initialized");
      } catch (e) {
        logln("Failed to initialize vault: $e");
        return SystemUnlockStatus.error;
      }
    }

    CoreMode.isUnlocked = true;

    return state;
  }
}
