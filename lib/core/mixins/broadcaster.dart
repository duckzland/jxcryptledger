import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../runtime/runtime.dart';
import '../ipc/client.dart';
import '../ipc/event.dart';
import '../ipc/server.dart';
import '../locator.dart';

mixin CoreMixinsBroadcaster {
  StreamSubscription? _broadcaster;

  CoreIpcClient get ipcClient => locator<CoreIpcClient>();
  CoreIpcServer get ipcServer => locator<CoreIpcServer>();

  bool isBroadcastable = CoreRuntime.instance.isServer();

  static final List<CoreIpcBroadcastEvent> _pendingEvents = [];
  static Timer? _debounceTimer;

  void broadcasterAction(CoreIpcBroadcastEvent event) {}

  void broadcasterListen() {
    try {
      _broadcaster = ipcClient.onBroadcast.listen((event) {
        if (!_pendingEvents.any((e) => e.isEqual(event))) {
          _pendingEvents.add(event);
        }

        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 32), _flushQueue);
      });
    } catch (_) {}
  }

  static void _flushQueue() {
    _pendingEvents.clear();
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
