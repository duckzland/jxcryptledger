import 'dart:async';
import 'dart:collection';

import '../ipc/event.dart';
import '../mixins/broadcaster.dart';
import '../ipc/protocol/reader.dart';
import '../ipc/registry.dart';
import '../mixins/emitter.dart';

abstract class CoreBaseBox<V> with CoreMixinsEmitter, CoreMixinsBroadcaster {
  final String boxName;
  final LinkedHashMap<dynamic, V> items = LinkedHashMap();
  StreamSubscription? ipcBus;

  CoreBaseBox(this.boxName) {
    broadcasterListen();
  }

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

  @override
  void broadcasterAction(CoreIpcBroadcastEvent event) {
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
    }

    emitterEmit(boxName);
  }

  void dispose() {
    broadcasterDispose();
    emitterDispose();
  }
}
