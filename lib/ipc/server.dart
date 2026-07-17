import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/abstracts/models/with_id.dart';
import '../core/log.dart';
import '../core/runtime/locator.dart';
import '../features/cryptos/service.dart';
import '../features/notification/service.dart';
import '../features/rates/service.dart';
import '../features/watchboard/tickers/service.dart';
import '../system/unlock/status.dart';
import 'action.dart';
import 'database/database.dart';
import 'protocol/buffer.dart';
import 'protocol/crypto.dart';
import 'protocol/packet.dart';
import 'protocol/reader.dart';
import 'protocol/writer.dart';

class IpcServer {
  final List<Socket> _slaves = [];
  final Uint8List sessionKey = IpcCrypto.createSessionKey(32);
  final IpcCrypto _crypto = IpcCrypto();

  ServerSocket? socket;

  IpcServer();

  late final IpcDatabase database;
  Future<SystemUnlockStatus> Function(Uint8List keyBytes)? unlocker;
  Future<void> Function()? shutdown;
  void Function()? disconnected;
  bool Function({int exclude})? hasClient;

  bool _isDisposing = false;

  String pipeName = "";

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

    ServerSocket socket;
    try {
      socket = await ServerSocket.bind(InternetAddress(pipeName, type: InternetAddressType.unix), 0);
      logln("[IPC] Server running: $pipeName");
    } catch (e) {
      logln("[IPC] Server failed to open: $pipeName with $e");
      return;
    }

    socket.listen((client) {
      if (_isDisposing) return;

      _slaves.add(client);

      final IpcBuffer incomingBuffer = IpcBuffer();

      Future<void> disconnect([dynamic error]) async {
        if (error != null) {
          logln("[IPC] Connection disconnected with error: $error");
        }

        _slaves.remove(client);
        try {
          client.destroy();
          disconnected?.call();
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

  Future<void> processFrames(Uint8List frame, IpcBuffer incomingBuffer, dynamic client) async {
    incomingBuffer.add(frame);

    IpcPacket? packet;
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
        IpcAction sendOp = actionCode;

        if (actionCode != IpcAction.unlock && actionCode != IpcAction.shutdown) {
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
          case IpcAction.put:
            await _writeToBox(action, nativeHiveKey, payload);
            broadcast(actionCode, action, rawKeyStr, payload, exclude: client);
            break;

          case IpcAction.delete:
            await database.delete(action, nativeHiveKey);
            broadcast(actionCode, action, rawKeyStr, Uint8List(0), exclude: client);
            break;

          case IpcAction.clear:
            await database.clear(action);
            broadcast(actionCode, action, '', Uint8List(0), exclude: client);
            break;

          case IpcAction.flush:
            await database.flush(action);
            break;

          case IpcAction.extract:
            final extracted = _extractFromBox(action);
            serializedResult = await _crypto.encrypt(extracted);
            break;

          case IpcAction.refreshRates:
            final service = locator<RatesService>();
            await service.refreshRates();
            break;

          case IpcAction.refreshCryptos:
            final service = locator<CryptosService>();
            await service.fetch();
            break;

          case IpcAction.notification:
            final service = locator<NotificationService>();
            final message = utf8.decode(payload);
            await service.show(message);
            break;

          case IpcAction.unlock:
            try {
              final SystemUnlockStatus status = await unlocker?.call(payload) ?? SystemUnlockStatus.error;
              final builder = BytesBuilder();
              if (status.isUnlocked()) {
                builder.add([status.value]);
                builder.add(sessionKey);
                sendOp = IpcAction.unlock;

                // Must broadcast so other instance mutate its screen to login screen!
                if (status.isFirstRun()) {
                  broadcast(actionCode, "database_created", '', Uint8List.fromList([status.value]), exclude: client);
                }
              } else {
                builder.add([status.value]);
                sendOp = IpcAction.response;
              }
              serializedResult = builder.toBytes();
            } catch (e) {
              serializedResult = Uint8List.fromList([0]);
            }

            break;

          case IpcAction.multiPut:
            await _batchWriteToBox(action, payload);
            broadcast(actionCode, action, "batch", payload, exclude: client);
            break;

          case IpcAction.addRateQueue:
            final parts = action.split("-");
            final sourceId = int.parse(parts[0]);
            final targetId = int.parse(parts[1]);
            final force = rawKeyStr == "true";
            final service = locator<RatesService>();
            service.addQueue(sourceId, targetId, force: force);
            break;

          case IpcAction.refreshTickers:
            final service = locator<TickersService>();
            await service.refreshRates();
            break;

          case IpcAction.replace:
            await database.clear(action);
            await _batchWriteToBox(action, payload);
            broadcast(actionCode, action, "replace", payload, exclude: client);
            break;

          case IpcAction.shutdown:
            if (hasClient != null && hasClient!.call(exclude: nativeHiveKey) == false) {
              await shutdown?.call();
              logln("Shutdown request from $nativeHiveKey... shutting down.");
            }
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

  void response(Socket client, int reqId, dynamic result, IpcAction op) {
    if (_isDisposing) return;
    final responsePacket = IpcPacket(reqId: reqId, op: op.code, action: '', key: '', payload: result);
    try {
      client.add(responsePacket.toBytes());
    } catch (e) {
      logln("[IPC] Failed to send response to $client");
      _slaves.remove(client);
      client.destroy();
      disconnected?.call();
    }
  }

  void error(Socket client, int activeReqId) {
    if (_isDisposing) return;
    final errorPacket = IpcPacket(reqId: activeReqId, op: IpcAction.error.code, action: '', key: '', payload: Uint8List(0));
    try {
      client.add(errorPacket.toBytes());
    } catch (e) {
      logln("[IPC] Failed to send error to $client");
      _slaves.remove(client);
      client.destroy();
      disconnected?.call();
    }
  }

  void broadcast(IpcAction op, String action, String key, Uint8List payload, {Socket? exclude}) async {
    if (_isDisposing) return;

    Uint8List finalPayload = payload;
    if (op != IpcAction.unlock && op != IpcAction.shutdown) {
      finalPayload = await _crypto.encrypt(finalPayload);
    }

    final packet = IpcPacket(reqId: -1, op: op.code, action: action, key: key, payload: finalPayload);
    final Uint8List frame = packet.toBytes();

    for (var slave in _slaves) {
      if (slave != exclude) {
        try {
          slave.add(frame);
        } catch (e) {
          logln("[IPC] Failed to broadcast to $slave");
          _slaves.remove(slave);
          slave.destroy();
          disconnected?.call();
        }
      }
    }
  }

  Future<void> _writeToBox(String boxName, dynamic id, Uint8List payload) async {
    final reader = IpcReader(payload);
    final adapter = database.adapters.get(boxName);
    final dynamic decoded = adapter.read(reader);
    final dynamic finalValue = decoded is MapEntry ? decoded.value : decoded;
    await database.put(boxName, id, finalValue);
  }

  Future<void> _batchWriteToBox(String boxName, Uint8List payload) async {
    final batchReader = IpcReader(payload);
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
    final writer = IpcWriter();
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
