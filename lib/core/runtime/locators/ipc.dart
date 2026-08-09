import '../../../ipc/client.dart';
import '../../../ipc/database/adapters.dart';
import '../../../ipc/server.dart';
import '../../locator.dart';
import '../adapters.dart';

Future<void> init() async {
  // IpcClient
  CoreLocator.getit.registerLazySingleton<IpcAdapters>(() => CoreRuntimeAdapters());
  CoreLocator.getit.registerLazySingleton<IpcClient>(() => IpcClient(CoreLocator.getit<IpcAdapters>()));

  // IpcServer
  CoreLocator.getit.registerLazySingleton<IpcServer>(() => IpcServer());
}
