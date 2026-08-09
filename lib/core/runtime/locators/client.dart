import '../../../features/archives/controller.dart';
import '../../../features/archives/repository.dart';
import '../../../features/rates/repository.dart';
import '../../../features/rates/controller.dart';
import '../../../features/cryptos/repository.dart';
import '../../../features/cryptos/controller.dart';
import '../../../features/watchboard/markets/controller.dart';
import '../../../features/watchboard/markets/repository.dart';
import '../../../system/error/controller.dart';
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
import '../../../system/unlock/controller.dart';
import '../../locator.dart';
import '../client.dart';
import './ipc.dart' as ipc;

Future<void> init() async {
  // IPC
  ipc.init();

  // Systems
  CoreLocator.getit.registerLazySingleton<SystemUnlockController>(() => SystemUnlockController());
  CoreLocator.getit.registerLazySingleton<SystemErrorController>(() => SystemErrorController());

  // Settings
  CoreLocator.getit.registerLazySingleton<SettingsRepository>(() => SettingsRepository());
  CoreLocator.getit.registerLazySingleton<SettingsController>(() => SettingsController(CoreLocator.getit<SettingsRepository>()));

  // States
  CoreLocator.getit.registerLazySingleton<StateController>(() => StateController(CoreLocator.getit<SettingsController>()));

  // Transactions
  CoreLocator.getit.registerLazySingleton<TransactionsRepository>(() => TransactionsRepository());
  CoreLocator.getit.registerLazySingleton<TransactionsController>(
    () => TransactionsController(CoreLocator.getit<TransactionsRepository>()),
  );

  // Cryptos
  CoreLocator.getit.registerLazySingleton<CryptosRepository>(() => CryptosRepository());
  CoreLocator.getit.registerLazySingleton<CryptosController>(() => CryptosController(CoreLocator.getit<CryptosRepository>()));

  // Rates
  CoreLocator.getit.registerLazySingleton<RatesRepository>(() => RatesRepository());
  CoreLocator.getit.registerLazySingleton<RatesController>(() => RatesController(CoreLocator.getit<RatesRepository>()));

  // Watchers
  CoreLocator.getit.registerLazySingleton<WatchersRepository>(() => WatchersRepository());
  CoreLocator.getit.registerLazySingleton<WatchersController>(
    () => WatchersController(CoreLocator.getit<WatchersRepository>(), CoreLocator.getit<CryptosController>()),
  );

  // Panels
  CoreLocator.getit.registerLazySingleton<PanelsRepository>(() => PanelsRepository());
  CoreLocator.getit.registerLazySingleton<PanelsController>(
    () => PanelsController(CoreLocator.getit<PanelsRepository>(), CoreLocator.getit<TransactionsRepository>()),
  );

  // Tickers
  CoreLocator.getit.registerLazySingleton<TickersRepository>(() => TickersRepository());
  CoreLocator.getit.registerLazySingleton<TickersController>(() => TickersController(CoreLocator.getit<TickersRepository>()));

  // Markets
  CoreLocator.getit.registerLazySingleton<MarketsRepository>(() => MarketsRepository());
  CoreLocator.getit.registerLazySingleton<MarketsController>(() => MarketsController(CoreLocator.getit<MarketsRepository>()));

  // Archives
  CoreLocator.getit.registerLazySingleton<ArchivesRepository>(() => ArchivesRepository());
  CoreLocator.getit.registerLazySingleton<ArchivesController>(() => ArchivesController(CoreLocator.getit<ArchivesRepository>()));

  // Higher level boots, this will most likely depends on the lower level to boot first.
  CoreLocator.getit.registerLazySingleton<CoreRuntimeClient>(() => CoreRuntimeClient());

  await CoreLocator.getit<CoreRuntimeClient>().init();
}
