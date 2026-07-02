import 'package:get_it/get_it.dart';
import 'package:jxledger/core/ipc/server.dart';

import '../../features/archives/controller.dart';
import '../../features/archives/repository.dart';
import '../../features/archives/service.dart';
import '../../features/notification/service.dart';
import '../../features/rates/repository.dart';
import '../../features/rates/service.dart';
import '../../features/rates/controller.dart';
import '../../features/cryptos/repository.dart';
import '../../features/cryptos/service.dart';
import '../../features/cryptos/controller.dart';
import '../../system/settings/controller.dart';
import '../../system/settings/repository.dart';
import '../../system/settings/service.dart';
import '../../system/settings/states.dart';
import '../../features/transactions/service.dart';
import '../../features/watchboard/panels/controller.dart';
import '../../features/watchboard/panels/repository.dart';
import '../../features/watchboard/panels/service.dart';
import '../../features/watchboard/tickers/controller.dart';
import '../../features/watchboard/tickers/repository.dart';
import '../../features/watchboard/tickers/service.dart';
import '../../features/transactions/controller.dart';
import '../../features/transactions/repository.dart';
import '../../features/watchers/controller.dart';
import '../../features/watchers/repository.dart';
import '../../features/watchers/service.dart';
import '../ipc/client.dart';
import '../worker.dart';
import 'bootstrap/client.dart';
import 'bootstrap/server.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // IpcClient
  locator.registerLazySingleton<CoreIpcClient>(() => CoreIpcClient());

  // IpcServer
  locator.registerLazySingleton<CoreIpcServer>(() => CoreIpcServer('jxledger'));

  // Settings
  locator.registerLazySingleton<SettingsRepository>(() => SettingsRepository());
  locator.registerLazySingleton<SettingsController>(() => SettingsController(locator<SettingsRepository>()));
  locator.registerLazySingleton<SettingsService>(() => SettingsService(locator<SettingsRepository>()));

  // States
  locator.registerLazySingleton<StateService>(() => StateService(locator<SettingsController>()));

  // Transactions
  locator.registerLazySingleton<TransactionsRepository>(() => TransactionsRepository());
  locator.registerLazySingleton<TransactionsController>(() => TransactionsController(locator<TransactionsRepository>()));
  locator.registerLazySingleton<TransactionsService>(() => TransactionsService(locator<TransactionsRepository>()));

  // Cryptos
  locator.registerLazySingleton<CryptosRepository>(() => CryptosRepository());
  locator.registerLazySingleton<CryptosService>(() => CryptosService(locator<CryptosRepository>(), locator<SettingsRepository>()));
  locator.registerLazySingleton<CryptosController>(() => CryptosController(locator<CryptosRepository>()));

  // Rates
  locator.registerLazySingleton<RatesRepository>(() => RatesRepository());
  locator.registerLazySingleton<RatesService>(() => RatesService(locator<RatesRepository>(), locator<SettingsRepository>()));
  locator.registerLazySingleton<RatesController>(() => RatesController(locator<RatesRepository>()));

  // Workers
  locator.registerLazySingleton<CoreWorker>(() => CoreWorker());

  // Watchers
  locator.registerLazySingleton<WatchersRepository>(() => WatchersRepository());
  locator.registerLazySingleton<WatchersController>(() => WatchersController(locator<WatchersRepository>(), locator<CryptosController>()));
  locator.registerLazySingleton<WatchersService>(
    () => WatchersService(locator<WatchersRepository>(), locator<NotificationService>(), locator<CryptosService>()),
  );

  // Notification
  locator.registerLazySingleton(() => NotificationService());

  // Panels
  locator.registerLazySingleton<PanelsRepository>(() => PanelsRepository());
  locator.registerLazySingleton<PanelsController>(() => PanelsController(locator<PanelsRepository>(), locator<TransactionsRepository>()));
  locator.registerLazySingleton<PanelsService>(() => PanelsService(locator<PanelsRepository>()));

  // Tickers
  locator.registerLazySingleton<TickersRepository>(() => TickersRepository());
  locator.registerLazySingleton<TickersController>(() => TickersController(locator<TickersRepository>()));
  locator.registerLazySingleton<TickersService>(() => TickersService(locator<TickersRepository>(), locator<SettingsRepository>()));

  // Archives
  locator.registerLazySingleton<ArchivesRepository>(() => ArchivesRepository());
  locator.registerLazySingleton<ArchivesController>(() => ArchivesController(locator<ArchivesRepository>()));
  locator.registerLazySingleton<ArchivesService>(() => ArchivesService(locator<ArchivesRepository>()));

  // Higher level boots, this will most likely depends on the lower level to boot first.
  locator.registerLazySingleton<CoreBootstrapServer>(() => CoreBootstrapServer());
  locator.registerLazySingleton<CoreBootstrapClient>(() => CoreBootstrapClient());
}
