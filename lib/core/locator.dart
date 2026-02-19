import 'package:get_it/get_it.dart';
import '../features/settings/repository.dart';
import '../features/settings/controller.dart';
import '../features/transactions/repository.dart'; // Add this
import '../features/transactions/controller.dart'; // Add this

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Settings
  locator.registerLazySingleton<SettingsRepository>(() => SettingsRepository());
  locator.registerLazySingleton<SettingsController>(
    () => SettingsController(locator<SettingsRepository>()),
  );

  // Transactions
  locator.registerLazySingleton<TransactionsRepository>(
    () => TransactionsRepository(),
  );
  locator.registerLazySingleton<TransactionsController>(
    () => TransactionsController(locator<TransactionsRepository>()),
  );
}
