import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/router.dart';
import '../../ipc/client.dart';
import '../../ipc/mixins/broadcaster.dart';
import '../../ipc/server.dart';
import '../runtime/locator.dart';
import '../runtime/process.dart';
import '../log.dart';
import '../mode.dart';

abstract class CoreBaseRuntime with IpcMixinsBroadcaster {
  CoreBaseRuntime();

  @override
  IpcClient get ipcClient => locator<IpcClient>();

  @override
  IpcServer get ipcServer => locator<IpcServer>();

  late final AppLifecycleListener lifecycleListener;

  Future<void> init();

  Future<bool> reconnect(IpcClient client);

  Future<void> shutdown();

  Future<void> setup() async {
    final dir = await getApplicationDocumentsDirectory();

    CoreMode.path = (kDebugMode || kProfileMode) ? p.normalize('${dir.path}/jxledger/dev') : p.normalize('${dir.path}/jxledger/live');
    CoreMode.ipcPipeName = p.normalize('${CoreMode.path}/jxledger.sock');

    final newDir = Directory(CoreMode.path);
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
      CoreMode.isFirstRun = true;
    }
  }

  Future<void> bindLifecycle() async {
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
  }

  Future<void> bindSignal() async {
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

  Future<bool> checkDatabaseExists() async {
    final settingsFile = File('${CoreMode.path}/settings_box.hive');
    CoreMode.isFirstRun = !await settingsFile.exists();
    return CoreMode.isFirstRun;
  }

  Future<void> spawnServer() async {
    try {
      ProcessStartMode detachmode = ProcessStartMode.detachedWithStdio;
      final List<String> serverArgs = ['--server'];
      if (kDebugMode || kProfileMode) {
        serverArgs.add('--development');
        detachmode = ProcessStartMode.detachedWithStdio;
      }

      final proc = await Process.start(Platform.resolvedExecutable, serverArgs, mode: detachmode);

      CoreMode.isMain = true;

      logln("Spawned detached IPC server process (pid=${proc.pid}) with flags: ${serverArgs.join(' ')}");
    } catch (e) {
      logln("Failed to spawn server: $e");
    }
  }

  Future<bool> waitForServer() async {
    for (var retries = 0; retries < 30; retries++) {
      try {
        if (isServerAvailable()) {
          final socket = await Socket.connect(InternetAddress(CoreMode.ipcPipeName, type: InternetAddressType.unix), 0);
          socket.destroy();
          return true;
        }
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    return false;
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
    try {
      final socketFile = FileSystemEntity.typeSync(CoreMode.ipcPipeName);
      if (socketFile != FileSystemEntityType.notFound) {
        File(CoreMode.ipcPipeName).deleteSync();
        logln("Cleaned up stale socket file prior to server spawn.");
      }
    } catch (e) {
      logln("Warning: Failed to clear stale socket file: $e");
    }
  }

  bool isServerAvailable() {
    return CoreProcessDetector.isServerInstanceRunning();
  }

  void fatalErrorNotice() {
    AppRouter.router.go('/error');
  }
}
