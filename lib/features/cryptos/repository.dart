import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

import 'model.dart';

class CryptosRepository extends ChangeNotifier {
  static const String boxName = 'cryptos_box';

  Box<CryptosModel> get _box => Hive.box<CryptosModel>(boxName);

  Map<int, String>? _symbolCache;

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<CryptosModel>(boxName);
    }
    notifyListeners();
  }

  void add(CryptosModel crypto) {
    _box.put(crypto.id, crypto);
    _symbolCache = null;
    notifyListeners();
  }

  List<CryptosModel> getAll() {
    return _box.values.toList();
  }

  List<CryptosModel> filter(String query) {
    final q = query.toLowerCase();
    return _box.values.where((c) => c.searchKey.contains(q)).toList();
  }

  void delete(int id) {
    _box.delete(id);
    _symbolCache = null;
    notifyListeners();
  }

  void clear() {
    _box.clear();
    _symbolCache = null;
    notifyListeners();
  }

  bool hasAny() {
    return _box.isNotEmpty;
  }

  Map<int, String> getSymbolMap() {
    if (_symbolCache != null) {
      return _symbolCache!;
    }

    final all = _box.values;

    _symbolCache = {for (var c in all) c.id: c.symbol};
    return _symbolCache!;
  }

  String? getSymbol(int id) {
    return getSymbolMap()[id];
  }

  CryptosModel? getById(int id) {
    return _box.get(id);
  }
}
