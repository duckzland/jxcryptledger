import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dart_ipc/dart_ipc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../system/settings/states.dart';
import '../log.dart';
import '../mode.dart';
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
          await Future.delayed(const Duration(milliseconds: 50));
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

    CoreMode.isServer = args.contains("--server");
    CoreMode.ipcPipeName = ipcPipeName;
    CoreMode.isMain = serverPid != 0;

    if (!CoreMode.isServer) {
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
        detachmode = ProcessStartMode.detachedWithStdio;
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
          final socket = await connect(CoreMode.ipcPipeName);
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
    if (!CoreMode.isServer) {
      final clt = locator<CoreBootstrapClient>();
      await clt.dispose();
    } else {
      final srv = locator<CoreBootstrapServer>();
      await srv.dispose();

      await stdout.close();
      await stderr.close();

      lifecycleListener.dispose();

      exit(0);
    }
  }
}
