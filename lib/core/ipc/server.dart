import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:hive_ce/hive_ce.dart';
import 'package:dart_ipc/dart_ipc.dart';

import '../abstracts/models/with_id.dart';
import '../runtime/runtime.dart';
import '../../features/cryptos/service.dart';
import '../../features/notification/service.dart';
import '../../features/rates/service.dart';
import '../locator.dart';
import '../log.dart';
import 'protocol/buffer.dart';
import 'database/database.dart';
import 'protocol/packet.dart';
import 'protocol/reader.dart';
import 'protocol/writer.dart';
import 'registry.dart';

class CoreIpcServer {
  final String pipeId;
  final List<Socket> _slaves = [];
  final Set<String> _activeSessions = {};
  ServerSocket? socket;
  bool _isShuttingDown = false;

  CoreIpcServer(this.pipeId);

  late final CoreIpcDatabase database;
  Future<bool> Function(String password, [Uint8List? keyBytes])? unlocker;
  Future<void> Function()? shutdown;

  Future<void> dispose() async {
    if (_isShuttingDown) return;
    _isShuttingDown = true;
    _activeSessions.clear();

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
    final socket = await bind(CoreRuntime.ipcPipeName);
    logln("[IPC] Server running: ${CoreRuntime.ipcPipeName}");

    socket.listen((client) {
      String? socketClientId;

      _slaves.add(client);

      final CoreIpcBuffer incomingBuffer = CoreIpcBuffer();

      Future<void> disconnect([dynamic error]) async {
        if (error != null) {
          logln("[IPC] Connection disconnected with error: $error");
        }

        _slaves.remove(client);
        if (_isShuttingDown) return;
        if (socketClientId != null) {
          _activeSessions.remove(socketClientId!);
          if (_activeSessions.length <= 1 && !CoreRuntime.instance.hasClient()) {
            await shutdown?.call();
          }
        }
      }

      client.listen(
        (frame) async {
          final registeredId = await processFrames(frame, incomingBuffer, client);
          if (registeredId != null) {
            socketClientId = registeredId;
          }
        },
        onDone: disconnect,
        onError: disconnect,
        cancelOnError: true,
      );
    });
  }

  Future<String?> processFrames(Uint8List frame, CoreIpcBuffer incomingBuffer, dynamic client) async {
    incomingBuffer.add(frame);
    String? registeredClientId;

    CoreIpcPacket? packet;
    while ((packet = incomingBuffer.parseNextAction()) != null) {
      final currentPacket = packet!;
      final activeReqId = currentPacket.reqId;
      final op = currentPacket.op;
      final boxName = currentPacket.boxName;
      final rawKeyStr = currentPacket.key;
      final valueBytes = currentPacket.valueBytes;

      try {
        dynamic result;
        final dynamic nativeHiveKey = int.tryParse(rawKeyStr) ?? rawKeyStr;

        switch (op) {
          case 0x02: // put
            final box = CoreIpcRegistry.getBox(boxName);
            final adapter = CoreIpcRegistry.getAdapter(boxName);
            dynamic finalValue;

            if (adapter is TypeAdapter<Map<dynamic, dynamic>>) {
              final valReader = CoreIpcReader(valueBytes);
              final dynamic decoded = adapter.read(valReader);
              finalValue = decoded;
              if (decoded is MapEntry) {
                finalValue = decoded.value;
              }
              await box.put(nativeHiveKey, finalValue);
            } else {
              final valReader = CoreIpcReader(valueBytes);
              final decoded = adapter.read(valReader);
              await box.put(nativeHiveKey, decoded);
            }

            broadcast(op, boxName, rawKeyStr, valueBytes, exclude: client);
            break;

          case 0x03: // delete
            final box = CoreIpcRegistry.getBox(boxName);
            await box.delete(nativeHiveKey);
            broadcast(op, boxName, rawKeyStr, Uint8List(0), exclude: client);
            break;

          case 0x04: // clear
            final box = CoreIpcRegistry.getBox(boxName);
            await box.clear();
            broadcast(op, boxName, '', Uint8List(0), exclude: client);
            break;

          case 0x05: // flush
            final box = CoreIpcRegistry.getBox(boxName);
            await box.flush();
            break;

          case 0x06: // extract
            final box = CoreIpcRegistry.getBox(boxName);
            final adapter = CoreIpcRegistry.getAdapter(boxName);
            final writer = CoreIpcWriter();

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
                  adapter.write(writer, value);
                }
              }
            }

            result = writer;
            break;

          case 0x07: // unlock
            final pw = utf8.decode(valueBytes);
            try {
              final success = await unlocker?.call(pw) ?? false;
              result = success;
            } catch (e) {
              logln("Failed to unlock: $e");
              result = false;
            }
            break;

          case 0x08: // register
            final String clientId = utf8.decode(valueBytes);
            registeredClientId = clientId;

            _activeSessions.add(clientId);
            result = true;
            break;

          case 0x09: // unregister
            final String clientId = utf8.decode(valueBytes);
            _activeSessions.remove(clientId);
            result = true;

            if (_activeSessions.length <= 1) {
              response(client, activeReqId, result);

              Future.delayed(const Duration(milliseconds: 50), () async {
                await shutdown?.call();
              });
              break;
            }
            break;

          case 0x10: // refresh rates
            final service = locator<RatesService>();
            await service.refreshRates();
            break;

          case 0x11: // refresh cryptos
            final service = locator<CryptosService>();
            await service.fetch();
            break;

          case 0x12: // notification
            final service = locator<NotificationService>();
            final message = utf8.decode(valueBytes);
            await service.show(message);
            break;

          case 0x13: // unlock with key
            try {
              final success = await unlocker?.call("", valueBytes) ?? false;
              result = success;
            } catch (e) {
              logln("Failed to unlock: $e");
              result = false;
            }
            break;

          case 0x14: // multi put (addAll)
            final box = CoreIpcRegistry.getBox(boxName);
            final adapter = CoreIpcRegistry.getAdapter(boxName);
            final batchReader = CoreIpcReader(valueBytes);
            final int totalItems = batchReader.readInt();

            for (int i = 0; i < totalItems; i++) {
              dynamic nativeHiveKey;
              dynamic finalValue;

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

            broadcast(op, boxName, "batch", valueBytes, exclude: client);
            break;

          case 0x15: // add rate queue
            final parts = boxName.split("-");
            final sourceId = int.parse(parts[0]);
            final targetId = int.parse(parts[1]);
            final force = rawKeyStr == "true";

            final service = locator<RatesService>();
            service.addQueue(sourceId, targetId, force: force);
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

    return registeredClientId;
  }

  void response(Socket client, int reqId, dynamic result) {
    final Uint8List resultBytes = _encode(result);
    final responsePacket = CoreIpcPacket(reqId: reqId, op: 0, boxName: '', key: '', valueBytes: resultBytes);
    client.add(responsePacket.toBytes());
  }

  void error(Socket client, int activeReqId) {
    final errorPacket = CoreIpcPacket(reqId: activeReqId, op: 0xFF, boxName: '', key: '', valueBytes: Uint8List(0));
    client.add(errorPacket.toBytes());
  }

  void broadcast(int op, String boxName, String key, Uint8List valueBytes, {Socket? exclude}) {
    final packet = CoreIpcPacket(reqId: -1, op: op, boxName: boxName, key: key, valueBytes: valueBytes);
    final Uint8List payload = packet.toBytes();

    for (var slave in _slaves) {
      if (slave != exclude) {
        slave.add(payload);
      }
    }
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
