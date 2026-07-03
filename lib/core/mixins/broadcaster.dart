import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../ipc/action.dart';
import '../mode.dart';
import '../ipc/client.dart';
import '../ipc/event.dart';
import '../ipc/server.dart';
import '../runtime/locator.dart';

mixin CoreMixinsBroadcaster {
  StreamSubscription? _broadcaster;

  CoreIpcClient get ipcClient => locator<CoreIpcClient>();
  CoreIpcServer get ipcServer => locator<CoreIpcServer>();

  bool isBroadcastable = CoreMode.isServer;

  void broadcasterAction(CoreIpcBroadcastEvent event) {}

  void broadcasterListen() {
    _broadcaster = ipcClient.onBroadcast.listen((event) {
      broadcasterAction(event);
    });
  }

  Future<void> broadcasterSend({required CoreIpcAction op, required String action, dynamic key, dynamic payload}) async {
    await ipcClient.send(op: op, action: action, key: key, payload: payload);
  }

  bool broadcasterEmit(CoreIpcAction op, String? action, String? key, Uint8List? payload, {Socket? exclude}) {
    if (!isBroadcastable) return false;
    ipcServer.broadcast(op, action ?? "", key ?? "", payload ?? Uint8List(0), exclude: exclude);
    return true;
  }

  void broadcasterDispose() {
    _broadcaster?.cancel();
  }
}
