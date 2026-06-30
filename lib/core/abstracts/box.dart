import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../ipc/event.dart';
import '../ipc/protocol/reader.dart';
import '../ipc/registry.dart';
import 'models/with_id.dart';

abstract class CoreBaseBox<V> {
  final String boxName;
  final LinkedHashMap<dynamic, V> items = LinkedHashMap();

  CoreBaseBox(this.boxName);

  Future<void> init();

  V? get(dynamic id) {
    return items[id];
  }

  V? getAt(int index) {
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

  Iterable<V> get values {
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

  List<V> extract() {
    return items.values.toList();
  }

  Map<dynamic, V> toMap() {
    return Map<dynamic, V>.from(items);
  }

  Future<void> put(dynamic id, V value) async {
    items[id] = value;
  }

  Future<void> delete(dynamic id) async {
    items.remove(id);
  }

  Future<int> clear() async {
    final int count = items.length;
    items.clear();
    return count;
  }

  Future<void> flush() async {
    return;
  }

  Future<void> refresh() async {
    await init();
  }

  Future<void> addAll(List<V> values) async {
    for (final entry in values.asMap().entries) {
      final value = entry.value;
      final index = entry.key;
      items[index] = value;
    }
  }

  Future<void> replace(List<V> values) async {
    items.clear();
    for (final entry in values.asMap().entries) {
      final value = entry.value;
      final index = entry.key;
      items[index] = value;
    }
  }

  void receive(CoreIpcBroadcastEvent event) {
    if (event.boxName != boxName) {
      return;
    }

    if (event.op == 0x02) {
      final adapter = CoreIpcRegistry.getAdapter(boxName);
      final reader = CoreIpcReader(event.valueBytes);
      final dynamic decodedItem = reader.read(null, adapter);

      if (decodedItem is V) {
        items[event.key] = decodedItem;
      }
    } else if (event.op == 0x03) {
      items.remove(event.key);
    } else if (event.op == 0x04) {
      items.clear();
    } else if (event.op == 0x14) {
      unpackBytes(event.valueBytes);
    } else if (event.op == 0x17) {
      items.clear();
      unpackBytes(event.valueBytes);
    }
  }

  void unpackBytes(Uint8List resultBytes) {
    final adapter = CoreIpcRegistry.getAdapter(boxName);
    final reader = CoreIpcReader(resultBytes);

    final int totalItems = reader.readInt();
    for (int i = 0; i < totalItems; i++) {
      final decoded = reader.read(null, adapter);
      final dynamic item = (decoded is MapEntry) ? decoded.value : decoded;
      final dynamic key = (item is CoreModelWithId) ? item.uuid : i;

      if (item is V) {
        items[key] = item;
      }
    }
  }
}
