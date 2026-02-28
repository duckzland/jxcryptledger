import 'package:get_it/get_it.dart';
import '../features/cryptos/controller.dart';
import '../features/rates/repository.dart';
import '../features/rates/service.dart';
import '../features/cryptos/repository.dart';
import '../features/cryptos/service.dart';
import '../features/settings/controller.dart';
import '../features/settings/repository.dart';
import '../features/transactions/controller.dart';
import '../features/transactions/repository.dart';

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
  locator.registerLazySingleton<CryptosController>(() => CryptosController(locator<CryptosRepository>()));

  // Rates
  locator.registerLazySingleton<RatesRepository>(() => RatesRepository());
  locator.registerLazySingleton<RatesService>(
    () => RatesService(locator<RatesRepository>(), locator<CryptosRepository>(), locator<SettingsRepository>()),
  );
}
