import 'package:hive_ce/hive_ce.dart';
import 'model.dart';

class CryptosRepository {
  static const String boxName = 'cryptos_box';

  Future<void> init() async {
    await Hive.openBox<CryptosModel>(boxName);
  }

  Future<void> add(CryptosModel crypto) async {
    final box = Hive.box<CryptosModel>(boxName);
    await box.put(crypto.id, crypto); // id is unique
  }

  Future<List<CryptosModel>> getAll() async {
    final box = Hive.box<CryptosModel>(boxName);
    return box.values.toList();
  }

  Future<List<CryptosModel>> filter(String query) async {
    final q = query.toLowerCase();
    final box = Hive.box<CryptosModel>(boxName);

    return box.values.where((c) => c.searchKey.contains(q)).toList();
  }

  Future<void> delete(int id) async {
    final box = Hive.box<CryptosModel>(boxName);
    await box.delete(id);
  }

  Future<void> clear() async {
    final box = Hive.box<CryptosModel>(boxName);
    await box.clear();
  }

  bool hasAny() {
    final box = Hive.box<CryptosModel>(boxName);
    return box.isNotEmpty;
  }
}
