import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../features/archives/service.dart';
import '../../features/cryptos/service.dart';
import '../../features/notification/service.dart';
import '../../features/rates/service.dart';
import '../../features/transactions/service.dart';
import '../../features/watchboard/markets/service.dart';
import '../../features/watchboard/panels/service.dart';
import '../../features/watchboard/tickers/service.dart';
import '../../features/watchers/service.dart';
import '../../ipc/action.dart';
import '../../ipc/client.dart';
import '../../ipc/database/adapters.dart';
import '../../ipc/database/database.dart';
import '../../system/encryption/service.dart';
import '../../system/settings/keys.dart';
import '../../system/settings/service.dart';
import '../../system/unlock/status.dart';
import '../abstracts/runtime.dart';
import '../locator.dart';
import '../log.dart';
import '../mode.dart';
import '../pooler.dart';
import 'boxes.dart';
import 'migration.dart';

class CoreRuntimeServer extends CoreBaseRuntime {
  CoreRuntimeServer();

  final SettingsService _settingsService = CoreLocator.getit<SettingsService>();
  final RatesService _ratesService = CoreLocator.getit<RatesService>();
  final WatchersService _watchersService = CoreLocator.getit<WatchersService>();
  final PanelsService _panelsService = CoreLocator.getit<PanelsService>();
  final TickersService _tickersService = CoreLocator.getit<TickersService>();
  final MarketsService _marketsService = CoreLocator.getit<MarketsService>();
  final TransactionsService _transactionsService = CoreLocator.getit<TransactionsService>();
  final CryptosService _cryptosService = CoreLocator.getit<CryptosService>();
  final ArchivesService _archivesService = CoreLocator.getit<ArchivesService>();
  final NotificationService _notificationService = CoreLocator.getit<NotificationService>();

  final CorePooler appPooler = CoreLocator.getit<CorePooler>();

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
    ipcServer.database = IpcDatabase(CoreRuntimeBoxes(), CoreLocator.getit<IpcAdapters>(), CoreRuntimeMigration());
    ipcServer.unlocker = unlock;
    ipcServer.shutdown = shutdown;
    ipcServer.disconnected = shutdownWhenNoClient;
    ipcServer.hasClient = hasClient;
    ipcServer.database.path = CoreMode.path;

    await ipcServer.database.init();
    await ipcServer.start();

    final serverReady = await waitForServer();
    if (!serverReady) {
      logln("Exiting due to failed to detect IPC server: ${CoreMode.ipcPipeName}", "RUNTIME");
      shutdown();
      return;
    }

    logln("IPC server running via Named Pipe: ${CoreMode.ipcPipeName}", "RUNTIME");

    // Client strapping up
    ipcClient.pipeName = CoreMode.ipcPipeName;
    ipcClient.reconnecting = reconnect;
    ipcClient.sessionKey = ipcServer.sessionKey;

    await ipcClient.start();

    logln("Connected to IPC server at Named Pipe: ${CoreMode.ipcPipeName}", "RUNTIME");

    _serverWatchdog = Timer.periodic(Duration(seconds: 5), (_) async {
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
      lifecycleListener?.dispose();
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

    await Future.delayed(Duration(milliseconds: 50));

    if (isServerAvailable()) {
      await client.start();

      await Future.delayed(Duration(milliseconds: 100));

      if (SystemEncryptionService.instance.isUnlocked()) {
        client.localKey = await SystemEncryptionService.instance.getRawKeyBytes();
        await client.send(op: IpcAction.unlock, action: "auth", key: "unlock", payload: client.localKey);
      }
      return true;
    }

    return false;
  }

  Future<void> bootServices() async {
    try {
      await _settingsService.init();
    } catch (e) {
      logln("SettingsService failed to initialize: $e", "RUNTIME");
    }

    try {
      await _notificationService.init();
    } catch (e) {
      logln("NotificationService failed to initialize: $e", "RUNTIME");
    }

    try {
      await _ratesService.init();
    } catch (e) {
      logln("RatesService failed to initialize: $e", "RUNTIME");
    }

    try {
      await _watchersService.init();
    } catch (e) {
      logln("WatchersService failed to initialize: $e", "RUNTIME");
    }

    try {
      await _panelsService.init();
    } catch (e) {
      logln("PanelsService failed to initialize: $e", "RUNTIME");
    }

    try {
      await _tickersService.init();
    } catch (e) {
      logln("TickersService failed to initialize: $e", "RUNTIME");
    }

    try {
      await _marketsService.init();
    } catch (e) {
      logln("MarketsService failed to initialize: $e", "RUNTIME");
    }

    try {
      await _cryptosService.init();
    } catch (e) {
      logln("CryptosService failed to initialize: $e", "RUNTIME");
    }

    try {
      await _archivesService.init();
    } catch (e) {
      logln("ArchivesService failed to initialize: $e", "RUNTIME");
    }

    try {
      await _transactionsService.init();
    } catch (e) {
      logln("TransactionsService failed to initialize: $e", "RUNTIME");
    }

    try {
      appPooler.start();
    } catch (e) {
      logln("WorkerService failed to initialize: $e", "RUNTIME");
    }

    logln("Server services started.", "RUNTIME");
  }

  Future<void> stopServices() async {
    await _settingsService.dispose();
    await _notificationService.dispose();
    await _ratesService.dispose();
    await _watchersService.dispose();
    await _panelsService.dispose();
    await _tickersService.dispose();
    await _marketsService.dispose();
    await _cryptosService.dispose();
    await _archivesService.dispose();
    await _transactionsService.dispose();

    appPooler.stop();

    logln("Server services stopped.", "RUNTIME");
  }

  void shutdownWhenNoClient() {
    if (!hasClient()) {
      logln("Exiting due to server has no more connected client", "RUNTIME");
      shutdown();
    }
  }

  Future<SystemUnlockStatus> unlock(Uint8List keyBytes) async {
    final SystemUnlockStatus state = await ipcServer.database.unlock(keyBytes);

    if (!state.isUnlocked()) {
      return state;
    }

    if (!state.isFirstRun()) {
      ipcClient.localKey = keyBytes;
      ipcClient.sessionKey ??= ipcServer.sessionKey;
      await bootServices();
      CoreMode.isFirstRun = false;
    }

    if (state.isFirstRun()) {
      CoreMode.isFirstRun = true;
      try {
        logln("First run detected, initializing vault", "RUNTIME");
        ipcClient.localKey = keyBytes;
        ipcClient.sessionKey ??= ipcServer.sessionKey;
        await bootServices();
        await _settingsService.save(SettingKey.vaultInitialized, "initialized");
      } catch (e) {
        logln("Failed to initialize vault: $e", "RUNTIME");
        return SystemUnlockStatus.error;
      }
    }

    CoreMode.isUnlocked = true;

    return state;
  }
}
