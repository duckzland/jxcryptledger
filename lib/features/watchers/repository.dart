import 'dart:convert';
import 'dart:math';

import 'package:hive_ce/hive_ce.dart';
import 'model.dart';

class WatchersRepository {
  static const boxName = 'watchers_box';

  Box<WatchersModel> get _box => Hive.box<WatchersModel>(boxName);

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<WatchersModel>(boxName);
    }
  }

  String generateWid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();

    while (true) {
      final now = DateTime.now().microsecondsSinceEpoch;
      final timePart = now.toRadixString(36).padLeft(4, '0');
      final timeSuffix = timePart.substring(timePart.length - 4);
      final randomPart = String.fromCharCodes(Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

      final id = '$timeSuffix$randomPart';
      if (!_box.containsKey(id)) {
        return id;
      }
    }
  }

  Future<List<WatchersModel>> getAll() async {
    final list = <WatchersModel>[];
    for (final key in _box.keys) {
      final tx = _box.get(key);
      if (tx != null) list.add(tx);
    }
    return list;
  }

  Future<void> saveAll(List<WatchersModel> wx) async {
    await _box.clear();
    for (final w in wx) {
      await _box.put(w.wid, w);
    }
  }

  Future<void> add(WatchersModel wx) async {
    return await _box.put(wx.wid, wx);
  }

  Future<void> update(WatchersModel wx) async {
    await _box.put(wx.wid, wx);
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  Future<int> clear() async {
    return await _box.clear();
  }

  bool isEmpty() {
    return _box.isEmpty;
  }

  Future<String> export() async {
    final items = _box.values.toList();
    final jsonList = items.map((tx) => tx.toJson()).toList();
    return jsonEncode(jsonList);
  }

  Future<void> import(String rawJson) async {
    final List<dynamic> decoded = jsonDecode(rawJson);
    final txs = decoded.map((e) => WatchersModel.fromJson(e as Map<String, dynamic>)).toList();

    await _box.clear();

    for (final tx in txs) {
      await _box.put(tx.wid, tx);
    }
  }
}
