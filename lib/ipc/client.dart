import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'abstracts/adapters.dart';
import 'status/op.dart';

import 'protocol/buffer.dart';
import 'protocol/converter.dart';
import 'protocol/crypto.dart';
import 'protocol/packet.dart';

import 'event.dart';

class IpcClient {
  final IpcAdapters adapters;
  late IpcConverter converter;

  IpcClient(this.adapters) {
    converter = IpcConverter(adapters);
  }

  final Map<int, Completer<dynamic>> _pending = {};
  final IpcBuffer _incomingBuffer = IpcBuffer();
  final StreamController<IpcBroadcastEvent> _broadcastController = StreamController<IpcBroadcastEvent>.broadcast();
  final IpcCrypto _crypto = IpcCrypto();

  bool _isDisposing = false;
  bool _isReconnecting = false;

  StreamSubscription<Uint8List>? _socketSubscription;
  VoidCallback? exited;
  Future<bool> Function(IpcClient client)? reconnecting;

  void Function(String message, [String group])? logger;

  Socket? _socket;
  int _nextReqId = 0;

  Uint8List? sessionKey;
  Uint8List? localKey;

  String pipeName = "";

  Stream<IpcBroadcastEvent> get onBroadcast => _broadcastController.stream;

  Future<void> start() async {
    if (pipeName.isEmpty) {
      throw StateError('[IPC] Refused to start with bad pipename');
    }

    if (_socket != null || _isDisposing) return;

    _isDisposing = false;
    _isReconnecting = false;

    try {
      _socket = await Socket.connect(InternetAddress(pipeName, type: InternetAddressType.unix), 0);

      _socketSubscription = _socket!.listen(
        (List<int> chunk) => _receive(Uint8List.fromList(chunk)),
        onError: (err) async {
          logger?.call("socket error: $err", "IPC");
          if (!_isDisposing) {
            await reconnect();
          }
        },
        onDone: () async {
          logger?.call("socket disconnected cleanly.", "IPC");
          if (!_isDisposing) {
            await reconnect();
          }
        },
        cancelOnError: true,
      );
      logger?.call("Socket connected to: $pipeName", "IPC");
    } catch (e) {
      logger?.call("connection failed: $e", "IPC");
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
      final success = await (reconnecting?.call(this) ?? Future.value(true));

      if (!success) {
        throw StateError('[IPC] Failed to perform clean reconnection');
      }
    } catch (e) {
      logger?.call("Failed to reconnect: $e", "IPC");
      exited?.call();
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

  Future<dynamic> send({required int op, required String action, dynamic key, dynamic payload}) async {
    Uint8List? bytes = converter.toBytes(op, action, payload);
    dynamic resultBytes;
    try {
      resultBytes = await _send(op: op, action: action, key: key, payload: bytes);
    } catch (e) {
      logger?.call("$e", "IPC");
    }

    return converter.fromBytes(op, action, resultBytes);
  }

  Future<dynamic> _send({required int op, required String action, dynamic key, Uint8List? payload}) async {
    final completer = Completer<dynamic>();
    final reqId = _nextReqId++;
    _pending[reqId] = completer;

    try {
      if (_socket == null) {
        throw StateError('[IPC] socket is not connected');
      }

      Uint8List rawPayload = payload ?? Uint8List(0);
      final opName = IpcStatusOp.getName(op);
      switch (opName) {
        case "unknown":
          throw StateError('[IPC] Cannot transmit database for unknown action.');

        // @todo: create proper callback for error
        case "error":
        case "unlock":
        case "shutdown":
          break;

        default:
          if (sessionKey == null || sessionKey!.isEmpty) {
            throw StateError('[IPC] Cannot transmit database requests before completing secure handshake. $op');
          }

          if (!_crypto.hasActiveKey) {
            _crypto.setSessionKey(sessionKey);
          }

          rawPayload = await _crypto.encrypt(rawPayload);
          break;
      }

      final packet = IpcPacket(reqId: reqId, op: op, action: action, key: key?.toString() ?? "", payload: rawPayload);

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

    IpcPacket? packet;
    _incomingBuffer.add(chunk);

    if (sessionKey != null && sessionKey!.isNotEmpty) {
      _crypto.setSessionKey(sessionKey);
    }

    while ((packet = _incomingBuffer.parseNextAction()) != null) {
      final currentPacket = packet!;
      Uint8List responseBytes = currentPacket.payload;

      final op = IpcStatusOp.getName(currentPacket.op);
      switch (op) {
        case "unknown":
          logger?.call("Refusing to process unknown request op", "IPC");
          break;

        // @todo: create proper callback for error
        case "error":
        case "shutdown":
        case "unlock":
          if (currentPacket.reqId == -1) {
            _broadcastPacket(currentPacket, responseBytes);
          }
          break;

        default:
          if (sessionKey == null) {
            logger?.call("Refusing to process op without sessionKey: $op", "IPC");
            break;
          }

          try {
            responseBytes = await _crypto.decrypt(responseBytes);
          } catch (e) {
            logger?.call("Failed to decrypt packet: $op - $e", "IPC");
            break;
          }

          if (currentPacket.reqId == -1) {
            _broadcastPacket(currentPacket, responseBytes);
          }

          break;
      }

      _closeBuffer(currentPacket, responseBytes);
    }
  }

  void _closeBuffer(IpcPacket packet, dynamic bytes) {
    final completer = _pending[packet.reqId];
    if (completer != null) {
      completer.complete(bytes);
      _pending.remove(packet.reqId);
    }
  }

  void _broadcastPacket(IpcPacket packet, dynamic bytes) {
    try {
      _broadcastController.add(
        IpcBroadcastEvent(
          op: packet.op,
          action: packet.action,
          key: packet.key,
          payload: converter.fromBytes(packet.op, packet.action, bytes),
        ),
      );
    } catch (e) {
      logger?.call("Failed to broadcast event: ${packet.op} - $e", "IPC");
    }
  }
}
