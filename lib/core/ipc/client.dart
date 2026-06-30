import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dart_ipc/dart_ipc.dart';

import '../../features/encryption/service.dart';
import '../mode.dart';
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

  bool _isDisposing = false;
  bool _isReconnecting = false;
  StreamSubscription<Uint8List>? _socketSubscription;
  VoidCallback? onExit;
  Socket? _socket;
  int _nextReqId = 0;

  Stream<CoreIpcBroadcastEvent> get onBroadcast => _broadcastController.stream;

  Future<void> start() async {
    if (_socket != null || _isDisposing) return;

    _isDisposing = false;
    _isReconnecting = false;

    try {
      _socket = await connect(CoreMode.ipcPipeName);

      _socketSubscription = _socket!.listen(
        (Uint8List chunk) => _receive(chunk),
        onError: (err) async {
          logln("[IPC] socket error: $err");
          if (!_isDisposing) {
            await reconnect();
          }
        },
        onDone: () async {
          logln("[IPC] socket disconnected cleanly.");
          if (!_isDisposing) {
            await reconnect();
          }
        },
        cancelOnError: true,
      );
      logln("[IPC] Socket connected to: ${CoreMode.ipcPipeName}");
    } catch (e) {
      logln("[IPC] connection failed: $e");
      if (!_isDisposing) {
        await reconnect();
      }
    }
  }

  Future<void> reconnect() async {
    if (_isDisposing || _isReconnecting) return;
    _isReconnecting = true;

    try {
      await destroy();

      if (!CoreMode.isServer) {
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
    } finally {
      _isReconnecting = false;
    }
  }

  Future<void> dispose() async {
    _isDisposing = true;
    await destroy();
    await _broadcastController.close();
  }

  Future<void> destroy() async {
    try {
      await _socketSubscription?.cancel();
    } catch (_) {}
    _socketSubscription = null;

    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;

    _incomingBuffer.clear();
    _nextReqId = 0;

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.complete(Uint8List(0));
      }
    }
    _pending.clear();
  }

  Future<Uint8List> send({required int op, required String box, dynamic key, List<int>? value}) async {
    return await _send(op: op, box: box, key: key, value: value);
  }

  Future<dynamic> _send({required int op, required String box, dynamic key, List<int>? value}) {
    final completer = Completer<dynamic>();
    final reqId = _nextReqId++;
    _pending[reqId] = completer;

    try {
      if (_socket == null) {
        throw StateError('[IPC] socket is not connected');
      }

      final packet = CoreIpcPacket(
        reqId: reqId,
        op: op,
        boxName: box,
        key: key?.toString() ?? "",
        valueBytes: value != null ? Uint8List.fromList(value) : Uint8List(0),
      );
      _socket!.add(packet.toBytes());
    } catch (e) {
      logln("[IPC] Send failed: $e");
      _pending.remove(reqId);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
    return completer.future;
  }

  void _receive(Uint8List chunk) {
    if (_isDisposing) return;
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
