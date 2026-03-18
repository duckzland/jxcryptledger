import 'package:hive_ce/hive_ce.dart';
import '../../core/abstracts/repository.dart';
import 'model.dart';

class CryptosRepository extends CoreBaseRepository<CryptosModel, int> {
  @override
  String get boxName => 'cryptos_box';

  Map<int, String>? _symbolCache;

  Future<void> init() async {
    _symbolCache = null;
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<CryptosModel>(boxName);
    }
  }

  @override
  void onAction() {
    _symbolCache = null;
  }

  Future<void> deleteById(int id) async {
    await box.delete(id);
    onAction();
  }

  List<CryptosModel> extract() {
    return box.values.cast<CryptosModel>().toList();
  }

  CryptosModel? getById(int id) {
    return box.get(id);
  }

  List<CryptosModel> filter(String query) {
    final q = query.toLowerCase();
    return box.values.cast<CryptosModel>().where((c) => c.searchKey.contains(q)).toList();
  }

  String? getSymbol(int id) {
    return getSymbolMap()[id];
  }

  Map<int, String> getSymbolMap() {
    if (_symbolCache != null) return _symbolCache!;
    final all = box.values.cast<CryptosModel>();
    return {for (var c in all) c.uuid: c.symbol};
  }
}
