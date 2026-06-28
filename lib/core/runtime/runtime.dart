import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/archives/adapter.dart';
import '../../features/cryptos/adapter.dart';
import '../../features/rates/adapter.dart';
import '../../features/settings/adapter.dart';
import '../../features/settings/states.dart';
import '../../features/transactions/adapter.dart';
import '../../features/watchboard/panels/adapter.dart';
import '../../features/watchboard/tickers/adapter.dart';
import '../../features/watchers/adapter.dart';
import '../bootstrap/client.dart';
import '../bootstrap/server.dart';
import '../ipc/client.dart';
import '../ipc/registry.dart';
import '../locator.dart';
import '../log.dart';
import 'process.dart';

class CoreRuntime {
  CoreRuntime._();
  static final CoreRuntime instance = CoreRuntime._();

  bool initialized = false;

  int serverPid = 0;

  late final AppLifecycleListener lifecycleListener;
  late final StateService states;

  static String get ipcPipeName {
    if (Platform.isWindows) {
      return kDebugMode ? r'\\.\pipe\com.jxledger_ipc_sync_pipe_dev' : r'\\.\pipe\com.jxledger_ipc_sync_pipe';
    } else {
      return kDebugMode ? '/tmp/jxledger.sock' : '/tmp/jxledger.sock';
    }
  }

  List<String> args = [];

  void setArgs(List<String> modeArgs) {
    args = modeArgs;
  }

  bool isServer() {
    return args.contains("--server");
  }

  bool isMain() {
    return serverPid != 0;
  }

  bool isServerAvailable() {
    return CoreProcessDetector.isServerInstanceRunning();
  }

  Future<void> init() async {
    if (initialized) return;

    // Not supporting web!
    if (kIsWeb) return;

    states = locator<StateService>();
    lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        try {
          await shutdown();
          return AppExitResponse.exit;
        } catch (e) {
          logln("Failed to clean exit: $e");
          return AppExitResponse.exit;
        }
      },
    );

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ProcessSignal.sigint.watch().listen((signal) async {
        try {
          await shutdown();
        } catch (e) {
          logln("Failed to save state on exit: $e");
        } finally {
          exit(0);
        }
      });
    }

    CoreIpcRegistry.registerAdapter('transactions_box', TransactionsAdapter());
    CoreIpcRegistry.registerAdapter('cryptos_box', CryptosAdapter());
    CoreIpcRegistry.registerAdapter('rates_box', RatesAdapter());
    CoreIpcRegistry.registerAdapter('watchers_box', WatchersAdapter());
    CoreIpcRegistry.registerAdapter('panels_box', PanelsAdapter());
    CoreIpcRegistry.registerAdapter('tickers_box', TickersAdapter());
    CoreIpcRegistry.registerAdapter('archives_box', ArchivesAdapter());
    CoreIpcRegistry.registerAdapter('settings_box', SettingsAdapter());

    if (!isServer()) {
      if (!isServerAvailable() && shouldSpawn()) {
        await spawnServer();
      }

      final serverReady = await waitForServer();
      if (!serverReady) {
        // @todo: Redirect to error instead?
        throw Exception("Failed to spawn IPC server (Named Pipe: $ipcPipeName timeout)");
      }
    } else {
      final serverStrap = locator<CoreBootstrapServer>();
      await serverStrap.start();

      logln("IPC server running via Named Pipe: $ipcPipeName");
    }

    final clientStrap = locator<CoreBootstrapClient>();
    await clientStrap.start();

    logln("Connected to IPC server at Named Pipe: $ipcPipeName");

    initialized = true;
  }

  bool hasOtherClient() {
    final List<int> activeClients = CoreProcessDetector.getActiveUiClientPids();

    if (activeClients.isEmpty || activeClients.length == 1) {
      return false;
    }

    return true;
  }

  bool shouldSpawn() {
    final List<int> activeClients = CoreProcessDetector.getActiveUiClientPids();

    if (activeClients.isEmpty) {
      return true;
    }

    if (!activeClients.contains(pid)) {
      activeClients.add(pid);
    }

    activeClients.sort();
    return activeClients.first == pid;
  }

  void cleanSocketFile() {
    if (Platform.isLinux) {
      final socketFile = File(ipcPipeName);

      if (socketFile.existsSync()) {
        try {
          socketFile.deleteSync();
          logln("Cleaned up stale Linux socket file prior to server spawn.");
        } catch (e) {
          logln("Warning: Failed to clear stale socket file: $e");
        }
      }
    }
  }

  Future<void> spawnServer() async {
    try {
      cleanSocketFile();

      final proc = await Process.start(Platform.resolvedExecutable, ['--server'], mode: ProcessStartMode.inheritStdio);
      serverPid = proc.pid;
      logln("Spawned detached IPC server process (pid=${proc.pid})");
    } catch (e) {
      logln("Failed to spawn server: $e");
    }
  }

  Future<bool> waitForServer() async {
    for (var retries = 0; retries < 30; retries++) {
      if (isServerAvailable()) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }

    return false;
  }

  Future<void> shutdown() async {
    if (!isServer()) {
      // @todo: figure out on how to save multiple app state!
      if (CoreRuntime.instance.isMain()) {
        await states.save();
      }

      final clt = locator<CoreIpcClient>();
      await clt.unregister();
      await clt.dispose();
    } else {
      final clt = locator<CoreIpcClient>();
      final srv = locator<CoreBootstrapServer>();

      await clt.dispose();
      await srv.stopServices();
      await srv.server.dispose();
      await srv.database.dispose();

      await stdout.close();
      await stderr.close();

      lifecycleListener.dispose();

      exit(0);
    }
  }
}
