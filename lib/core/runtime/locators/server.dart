import 'package:get_it/get_it.dart';
import 'package:jxledger/ipc/database/adapters.dart';
import 'package:jxledger/ipc/server.dart';

import '../../../features/archives/repository.dart';
import '../../../features/archives/service.dart';
import '../../../features/notification/service.dart';
import '../../../features/rates/repository.dart';
import '../../../features/rates/service.dart';
import '../../../features/cryptos/repository.dart';
import '../../../features/cryptos/service.dart';
import '../../../features/watchboard/markets/repository.dart';
import '../../../features/watchboard/markets/service.dart';
import '../../../system/settings/controller.dart';
import '../../../system/settings/repository.dart';
import '../../../system/settings/service.dart';
import '../../../system/settings/states.dart';
import '../../../features/transactions/service.dart';
import '../../../features/watchboard/panels/repository.dart';
import '../../../features/watchboard/panels/service.dart';
import '../../../features/watchboard/tickers/repository.dart';
import '../../../features/watchboard/tickers/service.dart';
import '../../../features/transactions/repository.dart';
import '../../../features/watchers/repository.dart';
import '../../../features/watchers/service.dart';
import '../../../ipc/client.dart';
import '../../pooler.dart';
import '../adapters.dart';
import '../server.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // IpcClient
  locator.registerLazySingleton<IpcAdapters>(() => CoreRuntimeAdapters());
  locator.registerLazySingleton<IpcClient>(() => IpcClient(locator<IpcAdapters>()));

  // IpcServer
  locator.registerLazySingleton<IpcServer>(() => IpcServer());

  // Settings
  locator.registerLazySingleton<SettingsRepository>(() => SettingsRepository());
  locator.registerLazySingleton<SettingsService>(() => SettingsService(locator<SettingsRepository>()));

  // States
  locator.registerLazySingleton<StateService>(() => StateService(locator<SettingsController>()));

  // Transactions
  locator.registerLazySingleton<TransactionsRepository>(() => TransactionsRepository());
  locator.registerLazySingleton<TransactionsService>(() => TransactionsService(locator<TransactionsRepository>()));

  // Cryptos
  locator.registerLazySingleton<CryptosRepository>(() => CryptosRepository());
  locator.registerLazySingleton<CryptosService>(() => CryptosService(locator<CryptosRepository>(), locator<SettingsRepository>()));

  // Rates
  locator.registerLazySingleton<RatesRepository>(() => RatesRepository());
  locator.registerLazySingleton<RatesService>(() => RatesService(locator<RatesRepository>(), locator<SettingsRepository>()));

  // Workers
  locator.registerLazySingleton<CorePooler>(() => CorePooler());

  // Notification
  locator.registerLazySingleton(() => NotificationService());

  // Watchers
  locator.registerLazySingleton<WatchersRepository>(() => WatchersRepository());
  locator.registerLazySingleton<WatchersService>(
    () => WatchersService(locator<WatchersRepository>(), locator<NotificationService>(), locator<CryptosService>()),
  );

  // Panels
  locator.registerLazySingleton<PanelsRepository>(() => PanelsRepository());
  locator.registerLazySingleton<PanelsService>(() => PanelsService(locator<PanelsRepository>()));

  // Tickers
  locator.registerLazySingleton<TickersRepository>(() => TickersRepository());
  locator.registerLazySingleton<TickersService>(
    () => TickersService(locator<TickersRepository>(), locator<SettingsRepository>(), locator<MarketsService>()),
  );

  // Markets
  locator.registerLazySingleton<MarketsRepository>(() => MarketsRepository());
  locator.registerLazySingleton<MarketsService>(() => MarketsService(locator<MarketsRepository>(), locator<SettingsRepository>()));

  // Archives
  locator.registerLazySingleton<ArchivesRepository>(() => ArchivesRepository());
  locator.registerLazySingleton<ArchivesService>(() => ArchivesService(locator<ArchivesRepository>()));

  // Higher level boots, this will most likely depends on the lower level to boot first.
  locator.registerLazySingleton<CoreRuntimeServer>(() => CoreRuntimeServer());
}

Future<void> init() async {
  await locator<CoreRuntimeServer>().init();
}
