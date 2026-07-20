import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import '../core/log.dart';

import 'database/adapters.dart';
import 'protocol/buffer.dart';
import 'protocol/converter.dart';
import 'protocol/crypto.dart';
import 'protocol/packet.dart';
import 'event.dart';
import 'action.dart';

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
      final success = await (reconnecting?.call(this) ?? Future.value(true));

      if (!success) {
        throw StateError('[IPC] Failed to perform clean reconnection');
      }
    } catch (e) {
      logln("[IPC] Failed to reconnect: $e");
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

  Future<dynamic> send({required IpcAction op, required String action, dynamic key, dynamic payload}) async {
    Uint8List? bytes = converter.toBytes(op, action, payload);

    final resultBytes = await _send(op: op, action: action, key: key, payload: bytes);
    return converter.fromBytes(op, action, resultBytes);
  }

  Future<dynamic> _send({required IpcAction op, required String action, dynamic key, Uint8List? payload}) async {
    final completer = Completer<dynamic>();
    final reqId = _nextReqId++;
    _pending[reqId] = completer;

    try {
      if (_socket == null) {
        throw StateError('[IPC] socket is not connected');
      }

      Uint8List rawPayload = payload ?? Uint8List(0);

      if (op != IpcAction.unlock && op != IpcAction.shutdown) {
        if (sessionKey == null) {
          throw StateError('[IPC] Cannot transmit database requests before completing secure handshake. $op');
        }

        if (!_crypto.hasActiveKey) {
          _crypto.setSessionKey(sessionKey);
        }

        rawPayload = await _crypto.encrypt(rawPayload);
      }

      final packet = IpcPacket(reqId: reqId, op: op.code, action: action, key: key?.toString() ?? "", payload: rawPayload);

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

      if (currentPacket.op != IpcAction.unlock.code && sessionKey != null) {
        try {
          if (!_crypto.hasActiveKey && sessionKey != null && sessionKey!.isNotEmpty) {
            _crypto.setSessionKey(sessionKey);
          }
          responseBytes = await _crypto.decrypt(responseBytes);
        } catch (e) {
          logln("[IPC] Failed to decrypt packet: $e");
          continue;
        }
      }

      if (currentPacket.op != IpcAction.unlock.code && sessionKey == null) {
        final completer = _pending[currentPacket.reqId];
        if (completer != null) {
          completer.complete(Uint8List(0));
          _pending.remove(currentPacket.reqId);
        }
        logln("[IPC] Failed to process packet for ${currentPacket.op}");
        continue;
      }

      // Protect the sessionKey, only update if there is actual bytes and serverKey isnt set yet!
      if (currentPacket.op == IpcAction.unlock.code && currentPacket.action != "database_created" && responseBytes.sublist(1).isNotEmpty) {
        sessionKey ??= responseBytes.sublist(1);
      }

      if (currentPacket.reqId == -1) {
        _broadcastController.add(
          IpcBroadcastEvent(
            op: currentPacket.op,
            action: currentPacket.action,
            key: currentPacket.key,
            payload: converter.fromBytes(IpcAction.fromCode(currentPacket.op), currentPacket.action, responseBytes),
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
