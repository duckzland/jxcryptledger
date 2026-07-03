import 'dart:collection';
import 'dart:typed_data';

import '../abstracts/models/with_id.dart';
import '../runtime/locator.dart';
import '../log.dart';

import 'action.dart';
import 'client.dart';
import 'database/adapters.dart';
import 'event.dart';
import 'protocol/writer.dart';
import 'protocol/reader.dart';

class CoreIpcBox<T extends CoreModelWithId> {
  final String boxName;
  final LinkedHashMap<dynamic, T> items = LinkedHashMap();
  final CoreIpcAdapters adapters;

  CoreIpcBox(this.boxName, this.adapters);

  CoreIpcClient get ipc => locator<CoreIpcClient>();

  Future<void> init() async {
    final resultBytes = await ipc.send(op: CoreIpcAction.extract, action: boxName);
    unpackBytes(resultBytes);
    logln("[IPC] Initialized standard box: $boxName|${items.length}");
  }

  T? get(dynamic id) {
    return items[id];
  }

  T? getAt(int index) {
    if (index < 0 || index >= items.length) {
      return null;
    } else {
      return items.values.elementAt(index);
    }
  }

  int get length {
    return items.length;
  }

  dynamic keyAt(int index) {
    if (index < 0 || index >= items.length) {
      return null;
    } else {
      return items.keys.elementAt(index);
    }
  }

  Iterable<T> get values {
    return items.values;
  }

  Iterable<dynamic> get keys {
    return items.keys;
  }

  bool get isEmpty {
    return items.isEmpty;
  }

  bool containsKey(dynamic id) {
    return items.containsKey(id);
  }

  List<T> extract() {
    return items.values.toList();
  }

  Map<dynamic, T> toMap() {
    return Map<dynamic, T>.from(items);
  }

  Future<void> put(dynamic id, T value) async {
    final writer = CoreIpcWriter();
    final boxAdapter = adapters.get(boxName);
    boxAdapter.write(writer, value);

    final bytes = writer.toBytes();
    await ipc.send(op: CoreIpcAction.put, action: boxName, key: id, payload: bytes);

    items[id] = value;
  }

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

  Future<void> delete(dynamic id) async {
    await ipc.send(op: CoreIpcAction.delete, action: boxName, key: id);
    items.remove(id);
  }

  Future<void> flush() async {
    await ipc.send(op: CoreIpcAction.flush, action: boxName);
  }

  Future<void> refresh() async {
    await init();
  }

  Future<void> addAll(List<T> values) async {
    if (values.isEmpty) return;

    final writer = CoreIpcWriter();
    final boxAdapter = adapters.get(boxName);

    writer.writeInt(values.length);

    for (final value in values) {
      boxAdapter.write(writer, value);
    }

    final bytes = writer.toBytes();
    await ipc.send(op: CoreIpcAction.multiPut, action: boxName, payload: bytes);

    for (final value in values) {
      items[value.uuid] = value;
    }
  }

  Future<void> replace(List<T> values) async {
    final writer = CoreIpcWriter();
    final boxAdapter = adapters.get(boxName);

    writer.writeInt(values.length);

    for (final value in values) {
      boxAdapter.write(writer, value);
    }

    final bytes = writer.toBytes();
    await ipc.send(op: CoreIpcAction.replace, action: boxName, payload: bytes);

    items.clear();
    for (final value in values) {
      items[value.uuid] = value;
    }
  }

  void receive(CoreIpcBroadcastEvent event) {
    if (event.action != boxName) {
      return;
    }

    if (event.actionCode == CoreIpcAction.put) {
      final adapter = adapters.get(boxName);
      final reader = CoreIpcReader(event.payload);
      final dynamic decodedItem = reader.read(null, adapter);

      if (decodedItem is T) {
        items[event.key] = decodedItem;
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

  void unpackBytes(Uint8List resultBytes) {
    final reader = CoreIpcReader(resultBytes);
    final int count = reader.readInt();
    final adapter = adapters.get(boxName);

    items.clear();

    for (var i = 0; i < count; i++) {
      final dynamic decodedItem = reader.read(null, adapter);
      if (decodedItem is T) {
        items[decodedItem.uuid] = decodedItem;
      }
    }
  }

  Future<void> add(T tx) async {
    await put(tx.uuid, tx);
  }

  Future<void> update(T tx) async {
    await add(tx);
  }

  Future<void> remove(T tx) async {
    await delete(tx.uuid);
  }
}
