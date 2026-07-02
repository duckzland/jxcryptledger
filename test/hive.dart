import 'dart:collection';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import 'package:jxledger/core/abstracts/models/with_id.dart';
import 'package:jxledger/core/ipc/action.dart';
import 'package:jxledger/core/ipc/box.dart';
import 'package:jxledger/core/ipc/client.dart';
import 'package:jxledger/core/ipc/event.dart';
import 'package:jxledger/core/ipc/protocol/reader.dart';
import 'package:jxledger/core/ipc/registry.dart';
import 'package:jxledger/core/log.dart';

class CoreHiveBoxStandard<T extends CoreModelWithId> implements CoreIpcBox<T> {
  @override
  final String boxName;

  @override
  final LinkedHashMap<dynamic, T> items = LinkedHashMap();

  final Box<T>? hiveBoxOverride;
  Box<T>? _hiveBox;

  CoreHiveBoxStandard(this.boxName, {this.hiveBoxOverride});

  Box<T> get _boxInstance {
    if (_hiveBox != null) return _hiveBox!;
    if (hiveBoxOverride != null) {
      _hiveBox = hiveBoxOverride!;
      return _hiveBox!;
    }
    throw StateError('Hive box "$boxName" has not been opened or provided.');
  }

  @override
  Future<void> init() async {
    if (_hiveBox == null && hiveBoxOverride == null) {
      if (!Hive.isBoxOpen(boxName)) {
        logln('[HIVE] Opening native box: $boxName');
        _hiveBox = await Hive.openBox<T>(boxName);
      } else {
        _hiveBox = Hive.box<T>(boxName);
      }
    }

    items.clear();
    for (final key in _boxInstance.keys) {
      final T? value = _boxInstance.get(key);
      if (value != null) {
        items[key] = value;
      }
    }
  }

  @override
  T? get(dynamic id) {
    return items[id];
  }

  @override
  T? getAt(int index) {
    if (index < 0 || index >= items.length) {
      return null;
    } else {
      return items.values.elementAt(index);
    }
  }

  @override
  int get length {
    return items.length;
  }

  @override
  dynamic keyAt(int index) {
    if (index < 0 || index >= items.length) {
      return null;
    } else {
      return items.keys.elementAt(index);
    }
  }

  @override
  Iterable<T> get values {
    return items.values;
  }

  @override
  Iterable<dynamic> get keys {
    return items.keys;
  }

  @override
  bool get isEmpty {
    return items.isEmpty;
  }

  @override
  bool containsKey(dynamic id) {
    return items.containsKey(id);
  }

  @override
  List<T> extract() {
    return items.values.toList();
  }

  @override
  Map<dynamic, T> toMap() {
    return Map<dynamic, T>.from(items);
  }

  @override
  Future<void> put(dynamic id, T value) async {
    await _boxInstance.put(id, value);
    items[id] = value;
  }

  @override
  Future<void> delete(dynamic id) async {
    await _boxInstance.delete(id);
    items.remove(id);
  }

  @override
  Future<int> clear() async {
    final count = _boxInstance.length;
    await _boxInstance.clear();
    items.clear();
    return count;
  }

  @override
  Future<void> flush() async {
    await _boxInstance.flush();
  }

  @override
  Future<void> refresh() async {
    await init();
  }

  @override
  Future<void> addAll(List<T> values) async {
    for (final value in values) {
      await _boxInstance.put(value.uuid, value);
      items[value.uuid] = value;
    }
  }

  @override
  Future<void> replace(List<T> values) async {
    await _boxInstance.clear();
    items.clear();
    await addAll(values);
  }

  @override
  void receive(CoreIpcBroadcastEvent event) {
    if (event.action != boxName) {
      return;
    }

    if (event.actionCode == CoreIpcAction.put) {
      final adapter = CoreIpcRegistry.getAdapter(boxName);
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

  @override
  void unpackBytes(Uint8List resultBytes) {
    final adapter = CoreIpcRegistry.getAdapter(boxName);
    final reader = CoreIpcReader(resultBytes);

    final int totalItems = reader.readInt();
    for (int i = 0; i < totalItems; i++) {
      final decoded = reader.read(null, adapter);
      final dynamic item = (decoded is MapEntry) ? decoded.value : decoded;
      final dynamic key = (item is CoreModelWithId) ? item.uuid : i;

      if (item is T) {
        items[key] = item;
      }
    }
  }

  @override
  CoreIpcClient get ipc => throw UnimplementedError();

  @override
  Future<void> add(T tx) async {
    await put(tx.uuid, tx);
  }

  @override
  Future<void> update(T tx) async {
    await add(tx);
  }

  @override
  Future<void> remove(T tx) async {
    await delete(tx.uuid);
  }
}
