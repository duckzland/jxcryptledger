import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../app/runtime.dart';
import '../ipc/client.dart';
import '../ipc/event.dart';
import '../ipc/server.dart';
import '../locator.dart';

mixin CoreMixinsBroadcaster {
  StreamSubscription? broadcaster;

  final CoreIpcClient ipcClient = locator<CoreIpcClient>();
  final IpcServer ipcServer = locator<IpcServer>();

  bool isBroadcastable = AppRuntime.instance.isServer();

  void broadcasterAction(CoreIpcBroadcastEvent event) {}

  void broadcasterListen() {
    try {
      final client = locator<CoreIpcClient>();

      broadcaster = client.onBroadcast.listen((event) {
        broadcasterAction(event);
      });
    } catch (_) {}
  }

  Future<void> broadcasterSend({required int op, required String box, dynamic key, List<int>? value}) async {
    await ipcClient.sendAction(op: op, box: box, key: key, value: value);
  }

  bool broadcasterEmit(int op, String? action, String? key, Uint8List? valueBytes, {Socket? exclude}) {
    if (isBroadcastable) {
      ipcServer.broadcast(op, action ?? "", key ?? "", valueBytes ?? Uint8List(0), exclude: exclude);
      return true;
    }
    return false;
  }

  void broadcasterDispose() {
    broadcaster?.cancel();
  }
}
