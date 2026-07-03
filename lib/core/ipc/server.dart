import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:dart_ipc/dart_ipc.dart';

import '../../features/watchboard/tickers/service.dart';
import '../../features/cryptos/service.dart';
import '../../features/notification/service.dart';
import '../../features/rates/service.dart';
import '../abstracts/models/with_id.dart';
import '../mode.dart';
import '../runtime/locator.dart';
import '../log.dart';

import 'protocol/buffer.dart';
import 'protocol/crypto.dart';
import 'protocol/packet.dart';
import 'protocol/reader.dart';
import 'protocol/writer.dart';

import 'database/database.dart';

import 'action.dart';

class CoreIpcServer {
  final String pipeId;
  final List<Socket> _slaves = [];
  final Uint8List sessionKey = CoreIpcCrypto.createSessionKey(32);
  final CoreIpcCrypto _crypto = CoreIpcCrypto();

  ServerSocket? socket;

  CoreIpcServer(this.pipeId);

  late final CoreIpcDatabase database;
  Future<bool> Function(Uint8List keyBytes)? unlocker;
  Future<void> Function()? shutdown;

  bool _isDisposing = false;

  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;

    for (var slave in List.from(_slaves)) {
      try {
        slave.destroy();
      } catch (_) {}
    }
    _slaves.clear();

    if (socket != null) {
      try {
        await socket!.close();
        socket = null;
      } catch (_) {}
    }

    database.dispose();
  }

  Future<void> start() async {
    _crypto.setSessionKey(sessionKey);

    final socket = await bind(CoreMode.ipcPipeName);
    logln("[IPC] Server running: ${CoreMode.ipcPipeName}");

    socket.listen((client) {
      if (_isDisposing) return;

      _slaves.add(client);

      final CoreIpcBuffer incomingBuffer = CoreIpcBuffer();

      Future<void> disconnect([dynamic error]) async {
        if (error != null) {
          logln("[IPC] Connection disconnected with error: $error");
        }

        _slaves.remove(client);
        try {
          client.destroy();
        } catch (_) {}
      }

      client.listen(
        (frame) async {
          if (_isDisposing) return;
          await processFrames(frame, incomingBuffer, client);
        },
        onDone: disconnect,
        onError: disconnect,
        cancelOnError: true,
      );
    });
  }

  Future<void> processFrames(Uint8List frame, CoreIpcBuffer incomingBuffer, dynamic client) async {
    incomingBuffer.add(frame);

    CoreIpcPacket? packet;
    while ((packet = incomingBuffer.parseNextAction()) != null) {
      if (_isDisposing) return;

      final currentPacket = packet!;
      final activeReqId = currentPacket.reqId;
      final actionCode = currentPacket.actionCode;
      final action = currentPacket.action;
      final rawKeyStr = currentPacket.key;
      Uint8List payload = currentPacket.payload;

      try {
        Uint8List serializedResult = await _crypto.encrypt(Uint8List(0));
        final dynamic nativeHiveKey = int.tryParse(rawKeyStr) ?? rawKeyStr;
        CoreIpcAction sendOp = actionCode;

        if (actionCode != CoreIpcAction.unlock) {
          if (payload.length < 28) {
            logln("[IPC] SECURITY VIOLATION: Received unauthenticated packet for op: $actionCode from reqId: $activeReqId. Rejecting.");
            error(client, activeReqId);
            continue;
          }

          try {
            payload = await _crypto.decrypt(payload);
          } catch (e) {
            logln("[IPC] AUTHENTICATION FAILURE: Tampered or invalid signature block for op: $actionCode. Dropping.");
            error(client, activeReqId);
            continue;
          }
        }

        switch (actionCode) {
          case CoreIpcAction.put:
            await _writeToBox(action, nativeHiveKey, payload);
            final encrypted = await _crypto.encrypt(payload);
            broadcast(actionCode, action, rawKeyStr, encrypted, exclude: client);
            break;

          case CoreIpcAction.delete:
            await database.delete(action, nativeHiveKey);
            final encrypted = await _crypto.encrypt(Uint8List(0));
            broadcast(actionCode, action, rawKeyStr, encrypted, exclude: client);
            break;

          case CoreIpcAction.clear:
            await database.clear(action);
            final encrypted = await _crypto.encrypt(Uint8List(0));
            broadcast(actionCode, action, '', encrypted, exclude: client);
            break;

          case CoreIpcAction.flush:
            await database.flush(action);
            break;

          case CoreIpcAction.extract:
            final extracted = _extractFromBox(action);
            serializedResult = await _crypto.encrypt(extracted);
            break;

          case CoreIpcAction.refreshRates:
            final service = locator<RatesService>();
            await service.refreshRates();
            break;

          case CoreIpcAction.refreshCryptos:
            final service = locator<CryptosService>();
            await service.fetch();
            break;

          case CoreIpcAction.notification:
            final service = locator<NotificationService>();
            final message = utf8.decode(payload);
            await service.show(message);
            break;

          case CoreIpcAction.unlock:
            try {
              final success = await unlocker?.call(payload) ?? false;
              final builder = BytesBuilder();
              if (success) {
                builder.add([1]);
                builder.add(sessionKey);
                sendOp = CoreIpcAction.unlock;
              } else {
                builder.add([0]);
                sendOp = CoreIpcAction.response;
              }
              serializedResult = builder.toBytes();
            } catch (e) {
              serializedResult = Uint8List.fromList([0]);
            }
            break;

          case CoreIpcAction.multiPut:
            await _batchWriteToBox(action, payload);
            final encrypted = await _crypto.encrypt(payload);
            broadcast(actionCode, action, "batch", encrypted, exclude: client);
            break;

          case CoreIpcAction.addRateQueue:
            final parts = action.split("-");
            final sourceId = int.parse(parts[0]);
            final targetId = int.parse(parts[1]);
            final force = rawKeyStr == "true";
            final service = locator<RatesService>();
            service.addQueue(sourceId, targetId, force: force);
            break;

          case CoreIpcAction.refreshTickers:
            final service = locator<TickersService>();
            await service.refreshRates();
            break;

          case CoreIpcAction.replace:
            await database.clear(action);
            await _batchWriteToBox(action, payload);
            final encrypted = await _crypto.encrypt(payload);
            broadcast(actionCode, action, "replace", encrypted, exclude: client);
            break;

          default:
            break;
        }

        response(client, activeReqId, serializedResult, sendOp);
      } catch (e) {
        logln("Failed to process action: $e");
        error(client, activeReqId);
      }
    }
  }

  void response(Socket client, int reqId, dynamic result, CoreIpcAction op) {
    if (_isDisposing) return;
    final responsePacket = CoreIpcPacket(reqId: reqId, op: op.code, action: '', key: '', payload: result);
    client.add(responsePacket.toBytes());
  }

  void error(Socket client, int activeReqId) {
    if (_isDisposing) return;
    final errorPacket = CoreIpcPacket(reqId: activeReqId, op: CoreIpcAction.error.code, action: '', key: '', payload: Uint8List(0));
    client.add(errorPacket.toBytes());
  }

  void broadcast(CoreIpcAction op, String action, String key, Uint8List payload, {Socket? exclude}) {
    if (_isDisposing) return;
    final packet = CoreIpcPacket(reqId: -1, op: op.code, action: action, key: key, payload: payload);
    final Uint8List frame = packet.toBytes();

    for (var slave in _slaves) {
      if (slave != exclude) {
        slave.add(frame);
      }
    }
  }

  Future<void> _writeToBox(String boxName, dynamic id, Uint8List payload) async {
    final reader = CoreIpcReader(payload);
    final adapter = database.adapters.get(boxName);
    final dynamic decoded = adapter.read(reader);
    final dynamic finalValue = decoded is MapEntry ? decoded.value : decoded;
    await database.put(boxName, id, finalValue);
  }

  Future<void> _batchWriteToBox(String boxName, Uint8List payload) async {
    final batchReader = CoreIpcReader(payload);
    final int totalItems = batchReader.readInt();
    final adapter = database.adapters.get(boxName);

    for (int i = 0; i < totalItems; i++) {
      dynamic nativeHiveKey;
      dynamic finalValue;
      
      finalValue = adapter.read(batchReader);
      nativeHiveKey = (finalValue is CoreModelWithId) ? finalValue.uuid : i;
      await database.put(boxName, nativeHiveKey, finalValue);
    }
  }

  Uint8List _extractFromBox(String boxName) {
    final writer = CoreIpcWriter();
    final adapter = database.adapters.get(boxName);
    final keys = database.keys(boxName);
    final int realCount = keys.length;
    writer.writeInt(realCount);

    for (var key in keys) {
      final dynamic value = database.get(boxName, key);

      if (value is Uint8List) {
        writer.writeByteList(value, writeLength: false);
      } else if (value != null) {
        adapter.write(writer, value);
      }
    }

    return writer.toBytes();
  }
}
