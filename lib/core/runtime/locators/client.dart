import 'package:get_it/get_it.dart';
import 'package:jxledger/ipc/database/adapters.dart';
import 'package:jxledger/ipc/server.dart';

import '../../../features/archives/controller.dart';
import '../../../features/archives/repository.dart';
import '../../../features/rates/repository.dart';
import '../../../features/rates/controller.dart';
import '../../../features/cryptos/repository.dart';
import '../../../features/cryptos/controller.dart';
import '../../../features/watchboard/markets/controller.dart';
import '../../../features/watchboard/markets/repository.dart';
import '../../../system/settings/controller.dart';
import '../../../system/settings/repository.dart';
import '../../../system/settings/states.dart';
import '../../../features/watchboard/panels/controller.dart';
import '../../../features/watchboard/panels/repository.dart';
import '../../../features/watchboard/tickers/controller.dart';
import '../../../features/watchboard/tickers/repository.dart';
import '../../../features/transactions/controller.dart';
import '../../../features/transactions/repository.dart';
import '../../../features/watchers/controller.dart';
import '../../../features/watchers/repository.dart';
import '../../../ipc/client.dart';
import '../adapters.dart';
import '../client.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // IpcClient
  locator.registerLazySingleton<IpcAdapters>(() => CoreRuntimeAdapters());
  locator.registerLazySingleton<IpcClient>(() => IpcClient(locator<IpcAdapters>()));

  // IpcServer
  locator.registerLazySingleton<IpcServer>(() => IpcServer());

  // Settings
  locator.registerLazySingleton<SettingsRepository>(() => SettingsRepository());
  locator.registerLazySingleton<SettingsController>(() => SettingsController(locator<SettingsRepository>()));

  // States
  locator.registerLazySingleton<StateService>(() => StateService(locator<SettingsController>()));

  // Transactions
  locator.registerLazySingleton<TransactionsRepository>(() => TransactionsRepository());
  locator.registerLazySingleton<TransactionsController>(() => TransactionsController(locator<TransactionsRepository>()));

  // Cryptos
  locator.registerLazySingleton<CryptosRepository>(() => CryptosRepository());
  locator.registerLazySingleton<CryptosController>(() => CryptosController(locator<CryptosRepository>()));

  // Rates
  locator.registerLazySingleton<RatesRepository>(() => RatesRepository());
  locator.registerLazySingleton<RatesController>(() => RatesController(locator<RatesRepository>()));

  // Watchers
  locator.registerLazySingleton<WatchersRepository>(() => WatchersRepository());
  locator.registerLazySingleton<WatchersController>(() => WatchersController(locator<WatchersRepository>(), locator<CryptosController>()));

  // Panels
  locator.registerLazySingleton<PanelsRepository>(() => PanelsRepository());
  locator.registerLazySingleton<PanelsController>(() => PanelsController(locator<PanelsRepository>(), locator<TransactionsRepository>()));

  // Tickers
  locator.registerLazySingleton<TickersRepository>(() => TickersRepository());
  locator.registerLazySingleton<TickersController>(() => TickersController(locator<TickersRepository>()));

  // Markets
  locator.registerLazySingleton<MarketsRepository>(() => MarketsRepository());
  locator.registerLazySingleton<MarketsController>(() => MarketsController(locator<MarketsRepository>()));

  // Archives
  locator.registerLazySingleton<ArchivesRepository>(() => ArchivesRepository());
  locator.registerLazySingleton<ArchivesController>(() => ArchivesController(locator<ArchivesRepository>()));

  // Higher level boots, this will most likely depends on the lower level to boot first.
  locator.registerLazySingleton<CoreRuntimeClient>(() => CoreRuntimeClient());
}

Future<void> init() async {
  await locator<CoreRuntimeClient>().init();
}
