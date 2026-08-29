import '../../../features/archives/repository.dart';
import '../../../features/archives/service.dart';
import '../../../features/notification/service.dart';
import '../../../features/rates/repository.dart';
import '../../../features/rates/service.dart';
import '../../../features/cryptos/repository.dart';
import '../../../features/cryptos/service.dart';
import '../../../features/watchboard/markets/repository.dart';
import '../../../features/watchboard/markets/service.dart';
import '../../../system/settings/repository.dart';
import '../../../system/settings/service.dart';
import '../../../features/transactions/service.dart';
import '../../../features/watchboard/panels/repository.dart';
import '../../../features/watchboard/panels/service.dart';
import '../../../features/watchboard/tickers/repository.dart';
import '../../../features/watchboard/tickers/service.dart';
import '../../../features/transactions/repository.dart';
import '../../../features/watchers/repository.dart';
import '../../../features/watchers/service.dart';
import '../../locator.dart';
import '../../pooler.dart';
import '../server.dart';
import 'ipc.dart' as ipc;

Future<void> init() async {
  // IPC
  ipc.init();

  // Settings
  CoreLocator.getit.registerLazySingleton<SettingsRepository>(() => SettingsRepository());
  CoreLocator.getit.registerLazySingleton<SettingsService>(() => SettingsService(CoreLocator.getit<SettingsRepository>()));

  // Transactions
  CoreLocator.getit.registerLazySingleton<TransactionsRepository>(() => TransactionsRepository());
  CoreLocator.getit.registerLazySingleton<TransactionsService>(() => TransactionsService(CoreLocator.getit<TransactionsRepository>()));

  // Cryptos
  CoreLocator.getit.registerLazySingleton<CryptosRepository>(() => CryptosRepository());
  CoreLocator.getit.registerLazySingleton<CryptosService>(
    () => CryptosService(CoreLocator.getit<CryptosRepository>(), CoreLocator.getit<SettingsRepository>()),
  );

  // Rates
  CoreLocator.getit.registerLazySingleton<RatesRepository>(() => RatesRepository());
  CoreLocator.getit.registerLazySingleton<RatesService>(
    () => RatesService(CoreLocator.getit<RatesRepository>(), CoreLocator.getit<SettingsRepository>()),
  );

  // Workers
  CoreLocator.getit.registerLazySingleton<CorePooler>(() => CorePooler());

  // Notification
  CoreLocator.getit.registerLazySingleton(() => NotificationService());

  // Watchers
  CoreLocator.getit.registerLazySingleton<WatchersRepository>(() => WatchersRepository());
  CoreLocator.getit.registerLazySingleton<WatchersService>(
    () => WatchersService(
      CoreLocator.getit<WatchersRepository>(),
      CoreLocator.getit<NotificationService>(),
      CoreLocator.getit<CryptosService>(),
    ),
  );

  // Panels
  CoreLocator.getit.registerLazySingleton<PanelsRepository>(() => PanelsRepository());
  CoreLocator.getit.registerLazySingleton<PanelsService>(() => PanelsService(CoreLocator.getit<PanelsRepository>()));

  // Tickers
  CoreLocator.getit.registerLazySingleton<TickersRepository>(() => TickersRepository());
  CoreLocator.getit.registerLazySingleton<TickersService>(
    () => TickersService(
      CoreLocator.getit<TickersRepository>(),
      CoreLocator.getit<SettingsRepository>(),
      CoreLocator.getit<MarketsService>(),
    ),
  );

  // Markets
  CoreLocator.getit.registerLazySingleton<MarketsRepository>(() => MarketsRepository());
  CoreLocator.getit.registerLazySingleton<MarketsService>(
    () => MarketsService(CoreLocator.getit<MarketsRepository>(), CoreLocator.getit<SettingsRepository>()),
  );

  // Archives
  CoreLocator.getit.registerLazySingleton<ArchivesRepository>(() => ArchivesRepository());
  CoreLocator.getit.registerLazySingleton<ArchivesService>(() => ArchivesService(CoreLocator.getit<ArchivesRepository>()));

  // Higher level boots, this will most likely depends on the lower level to boot first.
  CoreLocator.getit.registerLazySingleton<CoreRuntimeServer>(() => CoreRuntimeServer());

  await CoreLocator.getit<CoreRuntimeServer>().init();
}
