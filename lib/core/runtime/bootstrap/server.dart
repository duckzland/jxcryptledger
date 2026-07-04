import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../features/archives/service.dart';
import '../../../features/cryptos/service.dart';
import '../../../features/notification/service.dart';
import '../../../features/rates/service.dart';
import '../../../system/settings/keys.dart';
import '../../../system/settings/service.dart';
import '../../../features/transactions/service.dart';
import '../../../features/watchboard/panels/service.dart';
import '../../../features/watchboard/tickers/service.dart';
import '../../../features/watchers/service.dart';
import '../../../system/unlock/status.dart';
import '../../ipc/client.dart';
import '../../ipc/database/adapters.dart';
import '../../ipc/database/boxes.dart';
import '../../ipc/database/database.dart';
import '../../ipc/database/migration.dart';
import '../../ipc/server.dart';
import '../../log.dart';
import '../../mode.dart';
import '../../worker.dart';
import '../runtime.dart';
import '../locator.dart';

class CoreBootstrapServer {
  bool initialized = false;
  bool unlocked = false;
  bool isFirstRun = false;
  String? hivePath;

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

  late CoreIpcDatabase database;
  late CoreIpcServer server;
  late CoreIpcClient client;

  Timer? _serverWatchdog;

  Future<void> start() async {
    if (initialized) return;
    if (kIsWeb) return;

    database = CoreIpcDatabase(CoreIpcBoxes(), locator<CoreIpcAdapters>(), CoreIpcMigration());

    client = locator<CoreIpcClient>();
    server = locator<CoreIpcServer>();

    server.pipeName = CoreMode.ipcPipeName;
    server.database = database;
    server.unlocker = unlock;
    server.shutdown = CoreRuntime.instance.shutdown;

    await database.init();
    await server.start();

    _serverWatchdog = Timer.periodic(const Duration(seconds: 5), (_) async {
      final hasClient = CoreRuntime.instance.hasClient();
      if (hasClient) {
        logln("Server still has connected client");
      } else {
        logln("Server has no more connected client");
        CoreRuntime.instance.shutdown();
      }
    });

    initialized = true;
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

  Future<SystemUnlockStatus> unlock(Uint8List keyBytes) async {
    final SystemUnlockStatus state = await database.unlock(keyBytes);

    if (!state.isUnlocked()) {
      return state;
    }

    if (!state.isFirstRun()) {
      client.sessionKey ??= server.sessionKey;
      await bootServices();
    }

    if (state.isFirstRun()) {
      try {
        logln("First run detected, initializing vault");
        client.sessionKey ??= server.sessionKey;
        await _settingsService.save(SettingKey.vaultInitialized, "initialized");
      } catch (e) {
        logln("Failed to initialize vault: $e");
        return SystemUnlockStatus.error;
      }
    }

    return state;
  }

  Future<void> dispose() async {
    await client.dispose();
    await stopServices();
    await server.dispose();

    _serverWatchdog?.cancel();
    _serverWatchdog = null;
  }
}
