import 'package:hive_ce/hive_ce.dart';
import 'model.dart';

class CryptosRepository {
  static const String boxName = 'cryptos_box';

  Box<CryptosModel> get _box => Hive.box<CryptosModel>(boxName);

  Map<int, String>? _symbolCache;

  Future<void> init() async {
    _symbolCache = null;
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<CryptosModel>(boxName);
    }
  }

  Future<void> add(CryptosModel crypto) async {
    await _box.put(crypto.id, crypto);
    _symbolCache = null;
  }

  Future<void> delete(int id) async {
    await _box.delete(id);
    _symbolCache = null;
  }

  Future<void> clear() async {
    await _box.clear();
    _symbolCache = null;
  }

  Future<void> flush() async {
    await _box.flush();
    _symbolCache = null;
  }

  List<CryptosModel> getAll() {
    return _box.values.cast<CryptosModel>().toList();
  }

  CryptosModel? getById(int id) {
    return _box.get(id);
  }

  bool hasAny() {
    return _box.isNotEmpty;
  }

  List<CryptosModel> filter(String query) {
    final q = query.toLowerCase();
    return _box.values.cast<CryptosModel>().where((c) => c.searchKey.contains(q)).toList();
  }

  String? getSymbol(int id) {
    return getSymbolMap()[id];
  }

  Map<int, String> getSymbolMap() {
    if (_symbolCache != null) return _symbolCache!;
    final all = _box.values.cast<CryptosModel>();
    return {for (var c in all) c.id: c.symbol};
  }
}
