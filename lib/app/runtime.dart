import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dart_ipc/dart_ipc.dart'; // Added package import

import '../core/bootstrap/client.dart';
import '../core/bootstrap/server.dart';
import '../core/ipc/registry.dart';
import '../core/locator.dart';
import '../core/log.dart';
import '../features/archives/adapter.dart';
import '../features/cryptos/adapter.dart';
import '../features/rates/adapter.dart';
import '../features/settings/adapter.dart';
import '../features/transactions/adapter.dart';
import '../features/watchboard/panels/adapter.dart';
import '../features/watchboard/tickers/adapter.dart';
import '../features/watchers/adapter.dart';

class AppRuntime {
  AppRuntime._();
  static final AppRuntime instance = AppRuntime._();

  bool initialized = false;
  bool isMaster = true;

  int serverPid = 0;

  static String get ipcPipeName {
    if (Platform.isWindows) {
      return r'\\.\pipe\com.jxledger_ipc_sync_pipe';
    } else {
      return 'com.jxledger_ipc_sync_pipe';
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

  Future<void> init() async {
    if (initialized) return;

    // Not supporting web!
    if (kIsWeb) return;

    final available = await isServerAvailable();
    isMaster = !available;

    CoreIpcRegistry.registerAdapter('transactions_box', TransactionsAdapter());
    CoreIpcRegistry.registerAdapter('cryptos_box', CryptosAdapter());
    CoreIpcRegistry.registerAdapter('rates_box', RatesAdapter());
    CoreIpcRegistry.registerAdapter('watchers_box', WatchersAdapter());
    CoreIpcRegistry.registerAdapter('panels_box', PanelsAdapter());
    CoreIpcRegistry.registerAdapter('tickers_box', TickersAdapter());
    CoreIpcRegistry.registerAdapter('archives_box', ArchivesAdapter());
    CoreIpcRegistry.registerAdapter('settings_box', SettingsAdapter());

    if (isMaster) {
      if (!isServer()) {
        try {
          final proc = await Process.start(Platform.resolvedExecutable, ['--server'], mode: ProcessStartMode.inheritStdio);
          serverPid = proc.pid;
          logln("Spawned detached IPC server process (pid=${proc.pid})");
        } catch (e) {
          logln("Failed to spawn server: $e");
        }

        bool serverReady = false;
        for (var retries = 0; retries < 20; retries++) {
          if (await isServerAvailable()) {
            serverReady = true;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 150));
        }

        if (!serverReady) {
          throw Exception("Failed to spawn IPC server (Named Pipe: $ipcPipeName timeout)");
        }
      } else {
        final serverStrap = locator<CoreBootstrapServer>();
        await serverStrap.start();

        logln("IPC server running via Named Pipe: $ipcPipeName");
      }
    }

    final clientStrap = locator<CoreBootstrapClient>();
    await clientStrap.start();

    logln("Connected to IPC server at Named Pipe: $ipcPipeName");

    initialized = true;
  }

  Future<bool> isServerAvailable() async {
    try {
      final socket = await connect(ipcPipeName).timeout(const Duration(milliseconds: 150));
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}
