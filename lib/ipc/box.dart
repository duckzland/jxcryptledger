import 'dart:collection';

import '../core/abstracts/models/with_id.dart';
import '../core/log.dart';

import 'database/adapters.dart';
import 'action.dart';
import 'client.dart';
import 'event.dart';

class IpcBox<T extends CoreModelWithId> {
  final String boxName;
  final LinkedHashMap<dynamic, T> items = LinkedHashMap();
  final IpcAdapters adapters;
  final IpcClient client;

  IpcBox(this.boxName, this.adapters, this.client);

  Future<void> init() async {
    final results = await client.send(op: IpcAction.extract, action: boxName);
    for (final value in results) {
      final data = value as T;
      items[data.uuid] = data;
    }

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
    await client.send(op: IpcAction.put, action: boxName, key: id, payload: value);
    items[id] = value;
  }

  Future<int> clear() async {
    final count = await client.send(op: IpcAction.clear, action: boxName);
    items.clear();
    return count;
  }

  Future<void> delete(dynamic id) async {
    await client.send(op: IpcAction.delete, action: boxName, key: id);
    items.remove(id);
  }

  Future<void> flush() async {
    await client.send(op: IpcAction.flush, action: boxName);
  }

  Future<void> refresh() async {
    await init();
  }

  Future<void> addAll(List<T> values) async {
    if (values.isEmpty) return;

    await client.send(op: IpcAction.multiPut, action: boxName, payload: values);

    for (final value in values) {
      items[value.uuid] = value;
    }
  }

  Future<void> replace(List<T> values) async {
    await client.send(op: IpcAction.replace, action: boxName, payload: values);

    items.clear();
    for (final value in values) {
      items[value.uuid] = value;
    }
  }

  void receive(IpcBroadcastEvent event) {
    if (event.action != boxName) {
      return;
    }

    switch (event.actionCode) {
      case IpcAction.put:
        final data = event.payload as T;
        items[data.uuid] = data;
        break;

      case IpcAction.delete:
        items.remove(event.key);
        break;

      case IpcAction.clear:
        items.clear();
        break;

      case IpcAction.multiPut:
      case IpcAction.replace:
        items.clear();
        for (final value in event.payload) {
          final data = value as T;
          items[data.uuid] = data;
        }
        break;

      default:
        break;
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
