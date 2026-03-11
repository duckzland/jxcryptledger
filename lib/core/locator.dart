import 'package:get_it/get_it.dart';

import '../app/worker.dart';
import '../features/notification/service.dart';
import '../features/rates/repository.dart';
import '../features/rates/service.dart';
import '../features/rates/controller.dart';
import '../features/cryptos/repository.dart';
import '../features/cryptos/service.dart';
import '../features/cryptos/controller.dart';
import '../features/settings/controller.dart';
import '../features/settings/repository.dart';
import '../features/watchboard/panels/controller.dart';
import '../features/watchboard/panels/repository.dart';
import '../features/watchboard/tickers/controller.dart';
import '../features/watchboard/tickers/repository.dart';
import '../features/watchboard/tickers/service.dart';
import '../features/transactions/controller.dart';
import '../features/transactions/repository.dart';
import '../features/watchers/controller.dart';
import '../features/watchers/repository.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Settings
  locator.registerLazySingleton<SettingsRepository>(() => SettingsRepository());
  locator.registerLazySingleton<SettingsController>(() => SettingsController(locator<SettingsRepository>()));

  // Transactions
  locator.registerLazySingleton<TransactionsRepository>(() => TransactionsRepository());
  locator.registerLazySingleton<TransactionsController>(() => TransactionsController(locator<TransactionsRepository>()));

  // Cryptos
  locator.registerLazySingleton<CryptosRepository>(() => CryptosRepository());
  locator.registerLazySingleton<CryptosService>(() => CryptosService(locator<CryptosRepository>(), locator<SettingsRepository>()));
  locator.registerLazySingleton<CryptosController>(() => CryptosController(locator<CryptosRepository>(), locator<CryptosService>()));

  // Rates
  locator.registerLazySingleton<RatesRepository>(() => RatesRepository());
  locator.registerLazySingleton<RatesService>(
    () => RatesService(locator<RatesRepository>(), locator<CryptosRepository>(), locator<SettingsRepository>()),
  );
  locator.registerLazySingleton<RatesController>(() => RatesController(locator<RatesService>()));

  // Workers
  locator.registerLazySingleton<AppWorker>(() => AppWorker());

  // Watchers
  locator.registerLazySingleton<WatchersRepository>(() => WatchersRepository());
  locator.registerLazySingleton<WatchersController>(() => WatchersController(locator<WatchersRepository>(), locator<RatesService>()));

  // Notification
  locator.registerLazySingleton(() => NotificationService());

  // Panels
  locator.registerLazySingleton<PanelsRepository>(() => PanelsRepository());
  locator.registerLazySingleton<PanelsController>(
    () => PanelsController(locator<PanelsRepository>(), locator<RatesService>(), locator<TransactionsRepository>()),
  );

  // Tickers
  locator.registerLazySingleton<TickersRepository>(() => TickersRepository());
  locator.registerLazySingleton<TickersController>(() => TickersController(locator<TickersRepository>(), locator<TickersService>()));
  locator.registerLazySingleton<TickersService>(() => TickersService(locator<TickersRepository>(), locator<SettingsRepository>()));
}
