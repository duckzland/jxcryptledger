import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dart_ipc/dart_ipc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../features/archives/adapter.dart';
import '../../features/cryptos/adapter.dart';
import '../../features/rates/adapter.dart';
import '../../features/settings/adapter.dart';
import '../../features/settings/states.dart';
import '../../features/transactions/adapter.dart';
import '../../features/watchboard/panels/adapter.dart';
import '../../features/watchboard/tickers/adapter.dart';
import '../../features/watchers/adapter.dart';
import '../ipc/client.dart';
import '../ipc/registry.dart';
import '../log.dart';
import '../worker.dart';
import 'bootstrap/client.dart';
import 'bootstrap/server.dart';
import 'process.dart';
import 'locator.dart';

class CoreRuntime {
  CoreRuntime._();
  static final CoreRuntime instance = CoreRuntime._();

  bool initialized = false;

  int serverPid = 0;

  late final AppLifecycleListener lifecycleListener;
  late final StateService states;

  static String get ipcPipeName {
    if (Platform.isWindows) {
      final String username = Platform.environment['USERNAME'] ?? 'shared';
      final String safeUser = username.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      return kDebugMode
          // ignore: prefer_interpolation_to_compose_strings
          ? r'\\.\pipe\com.jxledger_ipc_sync_pipe_' + safeUser + '_devel'
          : r'\\.\pipe\com.jxledger_ipc_sync_pipe_' + safeUser;
    } else if (Platform.isLinux) {
      final String? xdgRuntime = Platform.environment['XDG_RUNTIME_DIR'];

      if (xdgRuntime != null && Directory(xdgRuntime).existsSync()) {
        return kDebugMode ? '$xdgRuntime/jxledger_devel.sock' : '$xdgRuntime/jxledger.sock';
      } else {
        final String username = Platform.environment['USER'] ?? Platform.environment['LOGNAME'] ?? 'shared';
        final String fallbackFolder = '/tmp/jxledger-$username';

        final Directory dir = Directory(fallbackFolder);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }

        return kDebugMode ? '$fallbackFolder/jxledger_devel.sock' : '$fallbackFolder/jxledger.sock';
      }
    } else {
      return kDebugMode ? '/tmp/jxledger_devel.sock' : '/tmp/jxledger.sock';
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
        logln("Failed to spawn IPC server (Named Pipe: $ipcPipeName timeout)");
        AppRouter.router.go('/error');
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

  bool hasClient() {
    final List<int> activeClients = CoreProcessDetector.getActiveUiClientPids();
    if (activeClients.isEmpty) {
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
      try {
        final socketFile = File(ipcPipeName);
        if (socketFile.existsSync()) {
          socketFile.deleteSync();
          logln("Cleaned up stale Linux socket file prior to server spawn.");
        }
      } catch (e) {
        logln("Warning: Failed to clear stale socket file: $e");
      }
    }
  }

  Future<void> spawnServer() async {
    try {
      cleanSocketFile();

      ProcessStartMode detachmode = ProcessStartMode.detachedWithStdio;
      final List<String> serverArgs = ['--server'];
      if (kDebugMode || kProfileMode) {
        serverArgs.add('--development');
        detachmode = ProcessStartMode.detached;
      }

      logln("Launching server with flags: ${serverArgs.join(' ')}");

      final proc = await Process.start(Platform.resolvedExecutable, serverArgs, mode: detachmode);

      serverPid = proc.pid;
      logln("Spawned detached IPC server process (pid=${proc.pid})");
    } catch (e) {
      logln("Failed to spawn server: $e");
    }
  }

  Future<bool> waitForServer() async {
    for (var retries = 0; retries < 30; retries++) {
      try {
        if (isServerAvailable()) {
          final socket = await connect(CoreRuntime.ipcPipeName);
          socket.destroy();
          return true;
        }
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
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

      locator<CoreWorker>().stop();

      exit(0);
    }
  }

  void hotReloadCleanup() {
    try {
      if (locator.isRegistered<CoreIpcClient>()) {
        locator<CoreIpcClient>().destroy();
      }
      if (isServer() && locator.isRegistered<CoreBootstrapServer>()) {
        locator<CoreBootstrapServer>().server.dispose();
      }
    } catch (e) {
      logln("Error cleaning sockets during reload: $e");
    }
  }
}
