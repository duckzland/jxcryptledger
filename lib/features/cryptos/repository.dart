import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

import 'model.dart';

class CryptosRepository extends ChangeNotifier {
  static const String boxName = 'cryptos_box';

  Box<CryptosModel> get _box => Hive.box<CryptosModel>(boxName);

  List<CryptosModel> get items => _box.values.cast<CryptosModel>().toList();

  Map<int, String>? _symbolCache;

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<CryptosModel>(boxName);
    }
    _symbolCache = null;
    notifyListeners();
  }

  Future<void> add(CryptosModel crypto) async {
    await _box.put(crypto.id, crypto);
    _symbolCache = null;
    notifyListeners();
  }

  List<CryptosModel> getAll() {
    return _box.values.cast<CryptosModel>().toList();
  }

  List<CryptosModel> filter(String query) {
    final q = query.toLowerCase();
    return _box.values.cast<CryptosModel>().where((c) => c.searchKey.contains(q)).toList();
  }

  Future<void> delete(int id) async {
    await _box.delete(id);
    _symbolCache = null;
    notifyListeners();
  }

  Future<void> clear() async {
    await _box.clear();
    _symbolCache = null;
    notifyListeners();
  }

  Future<void> flush() async {
    await _box.flush();
    notifyListeners();
  }

  bool hasAny() {
    return _box.isNotEmpty;
  }

  Map<int, String> getSymbolMap() {
    if (_symbolCache != null) {
      return _symbolCache!;
    }
    final all = _box.values.cast<CryptosModel>();
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
