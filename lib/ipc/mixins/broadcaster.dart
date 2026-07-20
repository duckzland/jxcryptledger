import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../core/log.dart';
import '../action.dart';
import '../client.dart';
import '../event.dart';
import '../server.dart';

mixin IpcMixinsBroadcaster {
  StreamSubscription? _broadcaster;

  IpcClient get ipcClient;
  IpcServer get ipcServer;

  bool get isBroadcastable => false;

  void broadcasterAction(IpcBroadcastEvent event) {}

  void broadcasterListen() {
    _broadcaster = ipcClient.onBroadcast.listen((event) {
      broadcasterAction(event);
    });
  }

  Future<void> broadcasterSend({required IpcAction op, required String action, dynamic key, dynamic payload}) async {
    try {
      await ipcClient.send(op: op, action: action, key: key, payload: payload);
    } catch (e) {
      logln("[IPC] Broadcaster failed to send: $e");
    }
  }

  bool broadcasterEmit(IpcAction op, String? action, String? key, Uint8List? payload, {Socket? exclude}) {
    if (!isBroadcastable) return false;
    try {
      ipcServer.broadcast(op, action ?? "", key ?? "", payload ?? Uint8List(0), exclude: exclude);
    } catch (e) {
      logln("[IPC] Broadcaster failed to emit: $e");
    }
    return true;
  }

  void broadcasterDispose() {
    _broadcaster?.cancel();
  }
}
