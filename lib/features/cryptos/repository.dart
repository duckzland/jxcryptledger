import 'package:hive_ce/hive_ce.dart';

import 'model.dart';

class CryptosRepository {
  static const String boxName = 'cryptos_box';

  Box<CryptosModel>? _box;
  Map<int, String>? _symbolCache;

  void _ensureBox() {
    if (_box != null) return;

    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box<CryptosModel>(boxName);
      return;
    }

    Hive.openBox<CryptosModel>(boxName);
    _box = Hive.box<CryptosModel>(boxName);
  }

  void add(CryptosModel crypto) {
    _ensureBox();
    _box!.put(crypto.id, crypto);
    _symbolCache = null;
  }

  List<CryptosModel> getAll() {
    _ensureBox();
    return _box!.values.toList();
  }

  List<CryptosModel> filter(String query) {
    _ensureBox();
    final q = query.toLowerCase();
    return _box!.values.where((c) => c.searchKey.contains(q)).toList();
  }

  void delete(int id) {
    _ensureBox();
    _box!.delete(id);
    _symbolCache = null;
  }

  void clear() {
    _ensureBox();
    _box!.clear();
    _symbolCache = null;
  }

  bool hasAny() {
    _ensureBox();
    return _box!.isNotEmpty;
  }

  Map<int, String> getSymbolMap() {
    if (_symbolCache != null) return _symbolCache!;

    _ensureBox();
    final all = _box!.values;

    _symbolCache = {for (var c in all) c.id: c.symbol};
    return _symbolCache!;
  }

  String? getSymbol(int id) {
    return getSymbolMap()[id];
  }
}
