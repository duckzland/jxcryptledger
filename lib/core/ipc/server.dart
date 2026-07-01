import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:hive_ce/hive_ce.dart';
import 'package:dart_ipc/dart_ipc.dart';

import '../../features/watchboard/tickers/service.dart';
import '../../features/cryptos/service.dart';
import '../../features/notification/service.dart';
import '../../features/rates/service.dart';
import '../../features/settings/adapter.dart';
import '../../features/settings/model.dart';
import '../abstracts/models/with_id.dart';
import '../mode.dart';
import '../runtime/locator.dart';
import '../log.dart';
import 'action.dart';
import 'protocol/buffer.dart';
import 'database/database.dart';
import 'protocol/packet.dart';
import 'protocol/reader.dart';
import 'protocol/writer.dart';
import 'registry.dart';

class CoreIpcServer {
  final String pipeId;
  final List<Socket> _slaves = [];
  ServerSocket? socket;

  CoreIpcServer(this.pipeId);

  late final CoreIpcDatabase database;
  Future<bool> Function(Uint8List keyBytes)? unlocker;
  Future<void> Function()? shutdown;

  Future<void> dispose() async {
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
  }

  Future<void> start() async {
    final socket = await bind(CoreMode.ipcPipeName);
    logln("[IPC] Server running: ${CoreMode.ipcPipeName}");

    socket.listen((client) {
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
      final currentPacket = packet!;
      final activeReqId = currentPacket.reqId;
      final actionCode = currentPacket.actionCode;
      final action = currentPacket.action;
      final rawKeyStr = currentPacket.key;
      final payload = currentPacket.payload;

      try {
        dynamic result;
        final dynamic nativeHiveKey = int.tryParse(rawKeyStr) ?? rawKeyStr;

        switch (actionCode) {
          case CoreIpcAction.put:
            final box = CoreIpcRegistry.getBox(action);
            final adapter = CoreIpcRegistry.getAdapter(action);
            await _writeValueToBox(box, adapter, nativeHiveKey, payload);
            broadcast(actionCode, action, rawKeyStr, payload, exclude: client);
            break;

          case CoreIpcAction.delete:
            final box = CoreIpcRegistry.getBox(action);
            await box.delete(nativeHiveKey);
            broadcast(actionCode, action, rawKeyStr, Uint8List(0), exclude: client);
            break;

          case CoreIpcAction.clear:
            final box = CoreIpcRegistry.getBox(action);
            await box.clear();
            broadcast(actionCode, action, '', Uint8List(0), exclude: client);
            break;

          case CoreIpcAction.flush:
            final box = CoreIpcRegistry.getBox(action);
            await box.flush();
            break;

          case CoreIpcAction.extract:
            final box = CoreIpcRegistry.getBox(action);
            final adapter = CoreIpcRegistry.getAdapter(action);
            result = _extractBoxContents(box, adapter);
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
              result = success;
            } catch (e) {
              logln("Failed to unlock: $e");
              result = false;
            }
            break;

          case CoreIpcAction.multiPut:
            final box = CoreIpcRegistry.getBox(action);
            final adapter = CoreIpcRegistry.getAdapter(action);
            await _writeBatchToBox(box, adapter, payload);
            broadcast(actionCode, action, "batch", payload, exclude: client);
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
            final box = CoreIpcRegistry.getBox(action);
            final adapter = CoreIpcRegistry.getAdapter(action);
            await box.clear();
            await _writeBatchToBox(box, adapter, payload);
            broadcast(actionCode, action, "replace", payload, exclude: client);
            break;

          default:
            break;
        }

        response(client, activeReqId, result);
      } catch (e) {
        logln("Failed to process action: $e");
        error(client, activeReqId);
      }
    }
  }

  void response(Socket client, int reqId, dynamic result) {
    final Uint8List resultBytes = _encode(result);
    final responsePacket = CoreIpcPacket(reqId: reqId, op: 0, action: '', key: '', payload: resultBytes);
    client.add(responsePacket.toBytes());
  }

  void error(Socket client, int activeReqId) {
    final errorPacket = CoreIpcPacket(reqId: activeReqId, op: CoreIpcAction.error.code, action: '', key: '', payload: Uint8List(0));
    client.add(errorPacket.toBytes());
  }

  void broadcast(CoreIpcAction op, String action, String key, Uint8List payload, {Socket? exclude}) {
    final packet = CoreIpcPacket(reqId: -1, op: op.code, action: action, key: key, payload: payload);
    final Uint8List frame = packet.toBytes();

    for (var slave in _slaves) {
      if (slave != exclude) {
        slave.add(frame);
      }
    }
  }

  Future<void> _writeValueToBox(Box box, TypeAdapter adapter, dynamic id, Uint8List payload) async {
    final reader = CoreIpcReader(payload);
    final dynamic decoded = adapter.read(reader);
    final dynamic finalValue = decoded is MapEntry ? decoded.value : decoded;
    await box.put(id, finalValue);
  }

  Future<void> _writeBatchToBox(Box box, TypeAdapter adapter, Uint8List payload) async {
    final batchReader = CoreIpcReader(payload);
    final int totalItems = batchReader.readInt();

    for (int i = 0; i < totalItems; i++) {
      dynamic nativeHiveKey;
      dynamic finalValue;

      // @deprecated Settings expected to use SettingsModel from this version onwards.
      if (adapter is TypeAdapter<Map<dynamic, dynamic>>) {
        final dynamic decoded = adapter.read(batchReader);
        if (decoded is MapEntry) {
          nativeHiveKey = decoded.key;
          finalValue = decoded.value;
        } else if (decoded is Map && decoded.isNotEmpty) {
          nativeHiveKey = decoded.keys.first;
          finalValue = decoded.values.first;
        } else {
          finalValue = decoded;
        }
      } else {
        finalValue = adapter.read(batchReader);
        nativeHiveKey = (finalValue is CoreModelWithId) ? finalValue.uuid : i;
      }

      await box.put(nativeHiveKey, finalValue);
    }
  }

  CoreIpcWriter _extractBoxContents(Box box, TypeAdapter adapter) {
    final writer = CoreIpcWriter();

    // @deprecated Settings expected to use SettingsModel from this version onwards.
    if (adapter is TypeAdapter<Map<dynamic, dynamic>>) {
      writer.writeInt(1);
      final mapPayload = <dynamic, dynamic>{};

      for (var key in box.keys) {
        final dynamic value = box.get(key);
        if (value is Map) {
          if (value.containsKey(key)) {
            mapPayload[key] = value[key];
          }
        } else {
          mapPayload[key] = value;
        }
      }

      writer.write(mapPayload, adapter: adapter);
    } else {
      final int realCount = box.keys.length;
      writer.writeInt(realCount);

      for (var key in box.keys) {
        final dynamic value = box.get(key);

        if (value is Uint8List) {
          writer.writeByteList(value, writeLength: false);
        } else if (value != null) {
          // @deprecated Settings expected to use SettingsModel from this version onwards.
          if (adapter is SettingsAdapter && value is! SettingsModel) {
            final String keyId = key.toString();
            final dynamic legacyValue = value is Map && value.isNotEmpty ? value[keyId] ?? value.values.first : value;
            final SettingsModel model = SettingsModel.fromLegacy(keyId, legacyValue);
            adapter.write(writer, model);
          } else {
            adapter.write(writer, value);
          }
        }
      }
    }

    return writer;
  }

  Uint8List _int32(int v) {
    final b = ByteData(4)..setInt32(0, v, Endian.big);
    return b.buffer.asUint8List();
  }

  Uint8List _encode(dynamic value) {
    if (value == null) return Uint8List(0);
    if (value is CoreIpcWriter) return value.toBytes();
    if (value is int) return _int32(value);
    if (value is bool) return Uint8List.fromList([value ? 1 : 0]);
    if (value is String) return utf8.encode(value);
    if (value is List) {
      final writer = CoreIpcWriter();
      writer.writeList(value);
      return writer.toBytes();
    }
    return Uint8List(0);
  }
}
