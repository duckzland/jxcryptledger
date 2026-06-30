import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dart_ipc/dart_ipc.dart';

import '../../features/encryption/service.dart';
import '../runtime/runtime.dart';
import '../log.dart';
import 'protocol/buffer.dart';
import 'protocol/packet.dart';
import 'event.dart';

class CoreIpcClient {
  final Map<int, Completer<dynamic>> _pending = {};
  final String uuid = "client_${DateTime.now().millisecondsSinceEpoch}_${StackTrace.current.hashCode}";
  final CoreIpcBuffer _incomingBuffer = CoreIpcBuffer();
  final StreamController<CoreIpcBroadcastEvent> _broadcastController = StreamController<CoreIpcBroadcastEvent>.broadcast();

  VoidCallback? onExit;
  Socket? _socket;
  int _nextReqId = 0;

  Stream<CoreIpcBroadcastEvent> get onBroadcast => _broadcastController.stream;

  Future<void> start() async {
    if (_socket != null) return;

    try {
      _socket = await connect(CoreRuntime.ipcPipeName);

      _socket!.listen(
        (Uint8List chunk) => _receive(chunk),
        onError: (err) async {
          logln("[IPC] socket error: $err");
          await reconnect();
        },
        onDone: () async {
          logln("[IPC] socket disconnected cleanly.");
          await reconnect();
        },
        cancelOnError: true,
      );
      logln("[IPC] Socket connected to: ${CoreRuntime.ipcPipeName}");
    } catch (e) {
      logln("[IPC] connection failed: $e");
      await reconnect();
    }
  }

  Future<void> reconnect() async {
    await destroy();

    if (!CoreRuntime.instance.isServer()) {
      await Future.delayed(const Duration(milliseconds: 500));

      if (CoreRuntime.instance.shouldSpawn() && !CoreRuntime.instance.isServerAvailable()) {
        await CoreRuntime.instance.spawnServer();
      }
    }

    await CoreRuntime.instance.waitForServer();

    if (CoreRuntime.instance.isServerAvailable()) {
      await start();

      await Future.delayed(const Duration(milliseconds: 100));

      if (EncryptionService.instance.isUnlocked()) {
        final keyBytes = await EncryptionService.instance.getRawKeyBytes();
        await send(op: 0x13, box: "auth", key: "unlock", value: keyBytes);
      }
      return;
    }

    onExit?.call();
  }

  Future<void> dispose() async {
    await destroy();
    await _broadcastController.close();
  }

  Future<void> destroy() async {
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;

    _incomingBuffer.clear();
    _nextReqId = 0;

    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete(Uint8List(0));
    }
    _pending.clear();
  }

  Future<Uint8List> send({required int op, required String box, dynamic key, List<int>? value}) async {
    return await _send(op: op, box: box, key: key, value: value);
  }

  Future<dynamic> _send({required int op, required String box, dynamic key, List<int>? value}) {
    final completer = Completer<dynamic>();
    try {
      final reqId = _nextReqId++;
      _pending[reqId] = completer;

      final packet = CoreIpcPacket(
        reqId: reqId,
        op: op,
        boxName: box,
        key: key?.toString() ?? "",
        valueBytes: value != null ? Uint8List.fromList(value) : Uint8List(0),
      );
      _socket?.add(packet.toBytes());
    } catch (e) {
      logln("[IPC] Send failed: $e");
    }
    return completer.future;
  }

  void _receive(Uint8List chunk) {
    CoreIpcPacket? packet;
    _incomingBuffer.add(chunk);

    while ((packet = _incomingBuffer.parseNextAction()) != null) {
      final currentPacket = packet!;

      if (currentPacket.reqId == -1) {
        _broadcastController.add(
          CoreIpcBroadcastEvent(
            op: currentPacket.op,
            boxName: currentPacket.boxName,
            key: currentPacket.key,
            valueBytes: currentPacket.valueBytes,
          ),
        );
        continue;
      }

      final Uint8List responseBytes = currentPacket.valueBytes;
      final completer = _pending[currentPacket.reqId];
      if (completer != null) {
        completer.complete(responseBytes);
        _pending.remove(currentPacket.reqId);
      }
    }
  }
}
