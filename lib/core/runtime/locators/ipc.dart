import '../../../ipc/client.dart';
import '../../../ipc/status/op.dart';
import '../../../ipc/server.dart';
import '../../locator.dart';
import '../ipc/adapters.dart';

Future<void> init() async {
  IpcStatusOp.register(0x00, "response");
  IpcStatusOp.register(0x02, "put");
  IpcStatusOp.register(0x03, "delete");
  IpcStatusOp.register(0x04, "clear");
  IpcStatusOp.register(0x05, "flush");
  IpcStatusOp.register(0x06, "extract");
  IpcStatusOp.register(0x07, "multiPut");
  IpcStatusOp.register(0x08, "replace");
  IpcStatusOp.register(0x09, "notification");
  IpcStatusOp.register(0x10, "unlock");
  IpcStatusOp.register(0x11, "addRateQueue");
  IpcStatusOp.register(0x12, "refreshTickers");
  IpcStatusOp.register(0x13, "refreshRates");
  IpcStatusOp.register(0x14, "refreshCryptos");
  IpcStatusOp.register(0x15, "refreshMarket");
  IpcStatusOp.register(0x16, "broadcast");
  IpcStatusOp.register(0x99, "shutdown");
  IpcStatusOp.register(0xFF, "error");

  // IpcClient
  CoreLocator.getit.registerLazySingleton<CoreRuntimeIpcAdapters>(() => CoreRuntimeIpcAdapters());
  CoreLocator.getit.registerLazySingleton<IpcClient>(() => IpcClient(CoreLocator.getit<CoreRuntimeIpcAdapters>()));

  // IpcServer
  CoreLocator.getit.registerLazySingleton<IpcServer>(() => IpcServer());
}
