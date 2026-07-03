import 'package:flutter/foundation.dart';

import '../../../app/constants.dart';
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
import '../../ipc/client.dart';
import '../../ipc/database/database.dart';
import '../../ipc/database/migration.dart';
import '../../ipc/server.dart';
import '../../log.dart';
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
  late CoreIpcMigration migrator;
  late CoreIpcServer server;
  late CoreIpcClient client;

  Future<void> start() async {
    if (initialized) return;
    if (kIsWeb) return;

    migrator = CoreIpcMigration();
    database = CoreIpcDatabase();

    client = locator<CoreIpcClient>();

    server = locator<CoreIpcServer>();
    server.database = database;
    server.unlocker = unlock;
    server.shutdown = CoreRuntime.instance.shutdown;

    await database.init();
    await server.start();

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
    appWorker.stop();
  }

  Future<bool> unlock(Uint8List keyBytes) async {
    final state = await database.unlock(keyBytes);

    if (state == unlockError) {
      return false;
    }

    if (state > unlockError) {
      client.sessionKey ??= server.sessionKey;
      await bootServices();
      await migrator.migrate();
    }

    if (state == unlockFirstTime) {
      try {
        logln("First run detected, initializing vault");
        client.sessionKey ??= server.sessionKey;
        await _settingsService.save(SettingKey.vaultInitialized, "initialized");
      } catch (e) {
        logln("Failed to initialize vault: $e");
        return false;
      }
    }

    return true;
  }

  Future<void> dispose() async {
    await client.dispose();
    await stopServices();
    await server.dispose();
  }
}
