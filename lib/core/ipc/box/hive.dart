import 'package:hive_ce/hive_ce.dart';

import '../../abstracts/box.dart';
import '../../abstracts/models/with_id.dart';
import '../../log.dart';

class CoreHiveBoxStandard<T extends CoreModelWithId> extends CoreBaseBox<T> {
  final Box<T>? hiveBoxOverride;
  Box<T>? _hiveBox;

  CoreHiveBoxStandard(super.boxName, {this.hiveBoxOverride});

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
}

class CoreHiveBoxDynamic extends CoreBaseBox<dynamic> {
  final Box<dynamic>? hiveBoxOverride;
  Box<dynamic>? _hiveBox;

  CoreHiveBoxDynamic(super.boxName, {this.hiveBoxOverride});

  Box<dynamic> get _boxInstance {
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
        logln('[HIVE] Opening native dynamic box: $boxName');
        _hiveBox = await Hive.openBox<dynamic>(boxName);
      } else {
        _hiveBox = Hive.box<dynamic>(boxName);
      }
    }

    items.clear();
    for (final key in _boxInstance.keys) {
      final dynamic value = _boxInstance.get(key);
      if (value != null) {
        items[key] = value;
      }
    }
  }

  @override
  Future<void> put(dynamic id, dynamic value) async {
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
  Future<void> addAll(List<dynamic> values) async {
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final key = (value is Map && value.containsKey('uuid')) ? value['uuid'] : i;
      await _boxInstance.put(key, value);
      items[key] = value;
    }
  }

  @override
  Future<void> replace(List<dynamic> values) async {
    await _boxInstance.clear();
    items.clear();
    await addAll(values);
  }
}
