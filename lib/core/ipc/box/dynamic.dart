import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import '../../abstracts/box.dart';
import '../../locator.dart';
import '../../log.dart';
import '../client.dart';
import '../protocol/reader.dart';
import '../protocol/writer.dart';
import '../registry.dart';

class CoreIpcBoxDynamic extends CoreBaseBox<dynamic> {
  CoreIpcBoxDynamic(super.boxName);

  CoreIpcClient get ipc => locator<CoreIpcClient>();

  @override
  Future<void> init() async {
    final resultBytes = await ipc.send(op: 0x06, box: boxName);
    unpackBytes(resultBytes);
    logln("[IPC] Initialized dynamic box: $boxName|${items.length}");
  }

  @override
  Future<void> put(dynamic id, dynamic value) async {
    final writer = CoreIpcWriter();
    final adapter = CoreIpcRegistry.getAdapter(boxName);
    final mapPayload = <dynamic, dynamic>{id: value};

    adapter.write(writer, mapPayload);

    await ipc.send(op: 0x02, box: boxName, key: id, value: writer.toBytes());
    items[id] = value;
    emitterEmit(boxName);
  }

  @override
  Future<int> clear() async {
    final resultBytes = await ipc.send(op: 0x04, box: boxName);
    if (resultBytes.isEmpty || resultBytes.length < 4) {
      items.clear();
      return 0;
    }
    final count = ByteData.sublistView(resultBytes).getInt32(0, Endian.big);
    items.clear();
    emitterEmit(boxName);
    return count;
  }

  @override
  Future<void> delete(dynamic id) async {
    await ipc.send(op: 0x03, box: boxName, key: id);
    items.remove(id);
    emitterEmit(boxName);
  }

  @override
  Future<void> flush() async {
    await ipc.send(op: 0x05, box: boxName);
  }

  Future<void> add(dynamic id, dynamic value) async {
    await put(id, value);
  }

  Future<void> update(dynamic id, dynamic value) async {
    await put(id, value);
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
