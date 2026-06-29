import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../runtime/runtime.dart';
import '../ipc/client.dart';
import '../ipc/event.dart';
import '../ipc/server.dart';
import '../runtime/locator.dart';

mixin CoreMixinsBroadcaster {
  StreamSubscription? _broadcaster;

  CoreIpcClient get ipcClient => locator<CoreIpcClient>();
  CoreIpcServer get ipcServer => locator<CoreIpcServer>();

  bool isBroadcastable = CoreRuntime.instance.isServer();

  void broadcasterAction(CoreIpcBroadcastEvent event) {}

  void broadcasterListen() {
    _broadcaster = ipcClient.onBroadcast.listen((event) {
      broadcasterAction(event);
    });
  }

  Future<void> broadcasterSend({required int op, required String box, dynamic key, List<int>? value}) async {
    await ipcClient.send(op: op, box: box, key: key, value: value);
  }

  bool broadcasterEmit(int op, String? action, String? key, Uint8List? valueBytes, {Socket? exclude}) {
    if (isBroadcastable) {
      ipcServer.broadcast(op, action ?? "", key ?? "", valueBytes ?? Uint8List(0), exclude: exclude);
      return true;
    }
    return false;
  }

  void broadcasterDispose() {
    _broadcaster?.cancel();
  }
}
