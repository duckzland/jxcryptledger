import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../action.dart';
import '../../core/mode.dart';
import '../client.dart';
import '../event.dart';
import '../server.dart';

mixin IpcMixinsBroadcaster {
  StreamSubscription? _broadcaster;

  IpcClient get ipcClient;
  IpcServer get ipcServer;

  bool isBroadcastable = CoreMode.isServer;

  void broadcasterAction(IpcBroadcastEvent event) {}

  void broadcasterListen() {
    _broadcaster = ipcClient.onBroadcast.listen((event) {
      broadcasterAction(event);
    });
  }

  Future<void> broadcasterSend({required IpcAction op, required String action, dynamic key, dynamic payload}) async {
    await ipcClient.send(op: op, action: action, key: key, payload: payload);
  }

  bool broadcasterEmit(IpcAction op, String? action, String? key, Uint8List? payload, {Socket? exclude}) {
    if (!isBroadcastable) return false;
    ipcServer.broadcast(op, action ?? "", key ?? "", payload ?? Uint8List(0), exclude: exclude);
    return true;
  }

  void broadcasterDispose() {
    _broadcaster?.cancel();
  }
}
