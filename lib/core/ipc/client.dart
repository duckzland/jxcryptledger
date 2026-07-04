import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:dart_ipc/dart_ipc.dart';

import '../log.dart';

import 'database/adapters.dart';
import 'protocol/buffer.dart';
import 'protocol/converter.dart';
import 'protocol/crypto.dart';
import 'protocol/packet.dart';
import 'event.dart';
import 'action.dart';

class CoreIpcClient {
  final CoreIpcAdapters adapters;
  late CoreIpcConverter converter;

  CoreIpcClient(this.adapters) {
    converter = CoreIpcConverter(adapters);
  }

  final Map<int, Completer<dynamic>> _pending = {};
  final String uuid = "client_${DateTime.now().millisecondsSinceEpoch}_${StackTrace.current.hashCode}";
  final CoreIpcBuffer _incomingBuffer = CoreIpcBuffer();
  final StreamController<CoreIpcBroadcastEvent> _broadcastController = StreamController<CoreIpcBroadcastEvent>.broadcast();
  final CoreIpcCrypto _crypto = CoreIpcCrypto();

  bool _isDisposing = false;
  bool _isReconnecting = false;

  StreamSubscription<Uint8List>? _socketSubscription;
  VoidCallback? onExit;
  Future<bool> Function(CoreIpcClient client)? onReconnect;

  Socket? _socket;
  int _nextReqId = 0;

  Uint8List? sessionKey;
  Uint8List? localKey;

  String pipeName = "";

  Stream<CoreIpcBroadcastEvent> get onBroadcast => _broadcastController.stream;

  Future<void> start() async {
    if (pipeName.isEmpty) {
      throw StateError('[IPC] Refused to start with bad pipename');
    }

    if (_socket != null || _isDisposing) return;

    _isDisposing = false;
    _isReconnecting = false;

    try {
      _socket = await connect(pipeName);

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
      logln("[IPC] Socket connected to: $pipeName");
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
      final success = await (onReconnect?.call(this) ?? Future.value(true));

      if (!success) {
        throw StateError('[IPC] Failed to perform clean reconnection');
      }
    } catch (e) {
      logln("[IPC] Failed to reconnect: $e");
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

  Future<dynamic> send({required CoreIpcAction op, required String action, dynamic key, dynamic payload}) async {
    Uint8List? bytes = converter.toBytes(op, action, payload);

    final resultBytes = await _send(op: op, action: action, key: key, payload: bytes);
    return converter.fromBytes(op, action, resultBytes);
  }

  Future<dynamic> _send({required CoreIpcAction op, required String action, dynamic key, Uint8List? payload}) async {
    final completer = Completer<dynamic>();
    final reqId = _nextReqId++;
    _pending[reqId] = completer;

    try {
      if (_socket == null) {
        throw StateError('[IPC] socket is not connected');
      }

      Uint8List rawPayload = payload ?? Uint8List(0);

      if (op != CoreIpcAction.unlock) {
        if (sessionKey == null) {
          throw StateError('[IPC] Cannot transmit database requests before completing secure handshake.');
        }

        if (!_crypto.hasActiveKey) {
          _crypto.setSessionKey(sessionKey);
        }

        rawPayload = await _crypto.encrypt(rawPayload);
      }

      final packet = CoreIpcPacket(reqId: reqId, op: op.code, action: action, key: key?.toString() ?? "", payload: rawPayload);

      _socket!.add(packet.toBytes());
    } catch (e) {
      _pending.remove(reqId);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }
    return completer.future;
  }

  Future<void> _receive(Uint8List chunk) async {
    if (_isDisposing) return;
    CoreIpcPacket? packet;
    _incomingBuffer.add(chunk);

    if (sessionKey != null) {
      _crypto.setSessionKey(sessionKey);
    }

    while ((packet = _incomingBuffer.parseNextAction()) != null) {
      final currentPacket = packet!;
      Uint8List responseBytes = currentPacket.payload;

      if (currentPacket.op != CoreIpcAction.unlock.code && sessionKey != null) {
        try {
          if (!_crypto.hasActiveKey) {
            _crypto.setSessionKey(sessionKey);
          }
          responseBytes = await _crypto.decrypt(responseBytes);
        } catch (e) {
          continue;
        }
      }

      if (currentPacket.op != CoreIpcAction.unlock.code && sessionKey == null) {
        final completer = _pending[currentPacket.reqId];
        if (completer != null) {
          completer.complete(Uint8List(0));
          _pending.remove(currentPacket.reqId);
        }
        continue;
      }

      if (currentPacket.op == CoreIpcAction.unlock.code) {
        sessionKey = responseBytes.sublist(1);
      }

      if (currentPacket.reqId == -1) {
        _broadcastController.add(
          CoreIpcBroadcastEvent(
            op: currentPacket.op,
            action: currentPacket.action,
            key: currentPacket.key,
            payload: converter.fromBytes(CoreIpcAction.fromCode(currentPacket.op), currentPacket.action, responseBytes),
          ),
        );
      } else {
        final completer = _pending[currentPacket.reqId];
        if (completer != null) {
          completer.complete(responseBytes);
          _pending.remove(currentPacket.reqId);
        }
      }
    }
  }
}
