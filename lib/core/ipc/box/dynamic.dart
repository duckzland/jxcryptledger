import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';
import 'package:jxledger/features/settings/model.dart';

import '../../abstracts/box.dart';
import '../../runtime/locator.dart';
import '../../log.dart';
import '../action.dart';
import '../client.dart';
import '../event.dart';
import '../protocol/reader.dart';
import '../protocol/writer.dart';
import '../registry.dart';

class CoreIpcBoxDynamic extends CoreBaseBox<dynamic> {
  CoreIpcBoxDynamic(super.boxName);

  CoreIpcClient get ipc => locator<CoreIpcClient>();

  @override
  Future<void> init() async {
    final resultBytes = await ipc.send(op: CoreIpcAction.extract, action: boxName);
    unpackBytes(resultBytes);
    logln("[IPC] Initialized dynamic box: $boxName|${items.length}");
  }

  @override
  Future<void> put(dynamic id, dynamic value) async {
    final writer = CoreIpcWriter();
    final adapter = CoreIpcRegistry.getAdapter(boxName);
    final mapPayload = <dynamic, dynamic>{id: value};

    // If this is the settings box and the UI passed raw/legacy values (string/map),
    // convert them to `SettingsModel` so the SettingsAdapter can serialize them
    // safely and the server receives typed models.
    if (boxName == 'settings_box') {
      final normalized = <dynamic, dynamic>{};
      mapPayload.forEach((k, v) {
        if (v is SettingsModel) {
          normalized[k] = v;
        } else {
          normalized[k] = SettingsModel.fromLegacy(k.toString(), v);
        }
      });
      adapter.write(writer, normalized);
    } else {
      adapter.write(writer, mapPayload);
    }

    await ipc.send(op: CoreIpcAction.put, action: boxName, key: id, payload: writer.toBytes());
    items[id] = value;
  }

  @override
  Future<int> clear() async {
    final resultBytes = await ipc.send(op: CoreIpcAction.clear, action: boxName);
    if (resultBytes.isEmpty || resultBytes.length < 4) {
      items.clear();
      return 0;
    }
    final count = ByteData.sublistView(resultBytes).getInt32(0, Endian.big);
    items.clear();

    return count;
  }

  @override
  Future<void> delete(dynamic id) async {
    await ipc.send(op: CoreIpcAction.delete, action: boxName, key: id);
    items.remove(id);
  }

  @override
  Future<void> flush() async {
    await ipc.send(op: CoreIpcAction.flush, action: boxName);
  }

  Future<void> add(dynamic id, dynamic value) async {
    await put(id, value);
  }

  Future<void> update(dynamic id, dynamic value) async {
    await put(id, value);
  }

  @override
  void receive(CoreIpcBroadcastEvent event) {
    if (event.action != boxName) {
      return;
    }

    if (event.actionCode == CoreIpcAction.put) {
      final adapter = CoreIpcRegistry.getAdapter(boxName);
      final reader = CoreIpcReader(event.payload);
      final decoded = adapter.read(reader);

      if (decoded is MapEntry) {
        items[event.key] = decoded.value;
      } else if (decoded is Map) {
        items[event.key] = decoded[event.key];
      } else {
        items[event.key] = decoded;
      }
    } else if (event.actionCode == CoreIpcAction.delete) {
      items.remove(event.key);
    } else if (event.actionCode == CoreIpcAction.clear) {
      items.clear();
    } else if (event.actionCode == CoreIpcAction.multiPut) {
      unpackBytes(event.payload);
    } else if (event.actionCode == CoreIpcAction.replace) {
      unpackBytes(event.payload);
    }
  }

  @override
  void unpackBytes(Uint8List resultBytes) {
    final adapter = CoreIpcRegistry.getAdapter(boxName);
    final reader = CoreIpcReader(resultBytes);

    final count = reader.readInt();
    final Map<String, dynamic> temporaryCache = {};

    if (adapter is TypeAdapter<Map<dynamic, dynamic>>) {
      if (count > 0) {
        final dynamic decodedMap = reader.read(null, adapter);
        if (decodedMap is Map) {
          decodedMap.forEach((k, v) {
            final String stringKey = k is Enum ? k.name : k.toString();
            if (v is Map) {
              if (v.containsKey(stringKey)) {
                temporaryCache[stringKey] = v[stringKey];
              }
            } else {
              temporaryCache[stringKey] = v;
            }
          });
        }
      }
    } else {
      for (var i = 0; i < count; i++) {
        final dynamic decodedItem = reader.read(null, adapter);

        if (decodedItem is Map) {
          decodedItem.forEach((k, v) {
            final String stringKey = k is Enum ? k.name : k.toString();
            temporaryCache[stringKey] = v;
          });
        }
      }
    }
    items.clear();
    items.addAll(temporaryCache);
  }
}
