import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_ipc/dart_ipc.dart';

import '../../app/runtime.dart';
import '../log.dart';
import 'protocol/buffer.dart';
import 'protocol/packet.dart';
import 'event.dart';

class CoreIpcClient {
  Socket? _socket;
  bool _connected = false;
  final Map<int, Completer<dynamic>> _pending = {};
  int _nextReqId = 0;

  final String uuid = "client_${DateTime.now().millisecondsSinceEpoch}_${StackTrace.current.hashCode}";

  final CoreIpcBuffer _incomingBuffer = CoreIpcBuffer();

  final StreamController<CoreIpcBroadcastEvent> _broadcastController = StreamController<CoreIpcBroadcastEvent>.broadcast();

  Stream<CoreIpcBroadcastEvent> get onBroadcast => _broadcastController.stream;

  Future<void> start() async {
    if (_connected && _socket != null) {
      return;
    }

    try {
      _socket = await connect(AppRuntime.ipcPipeName);
      _socket!.listen(
        (Uint8List chunk) => _onDataReceived(chunk),
        onError: (err) => logln("[IPC] socket error: $err"),
        onDone: () {
          _connected = false;
        },
        cancelOnError: true,
      );

      _connected = true;
    } catch (e) {
      logln("[IPC] connection failed: $e");
      rethrow;
    }
  }

  Future<Uint8List> sendAction({required int op, required String box, dynamic key, List<int>? value}) async {
    try {
      final result = await _send(op: op, box: box, key: key, value: value);
      if (result == null) {
        return Uint8List(0);
      }
      return result;
    } catch (e) {
      return Uint8List(0);
    }
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
      logln("[IPC] Failed to Send Action: $e");
    }

    return completer.future;
  }

  void _onDataReceived(Uint8List chunk) {
    _incomingBuffer.add(chunk);
    _processIncomingFrames();
  }

  void _processIncomingFrames() {
    CoreIpcPacket? packet;

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

  void dispose() {
    _broadcastController.close();
    _socket?.close();
  }

  Future<void> register() async {
    await sendAction(op: 0x08, box: "auth", key: "register", value: utf8.encode(uuid));
  }

  Future<void> unregister() async {
    await sendAction(op: 0x09, box: "auth", key: "unregister", value: utf8.encode(uuid));
  }
}
