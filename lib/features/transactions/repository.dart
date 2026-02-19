import 'package:hive/hive.dart';
import 'model.dart';
import '../../core/encryption_service.dart';
import '../../core/filter_isolate.dart';

class TransactionRepository {
  static const String boxName = 'TransactionModels_box';

  final EncryptionService _encryption = EncryptionService.instance;
  final FilterIsolate _filter = FilterIsolate();

  Future<void> init() async {
    await _filter.init();
    await Hive.openBox<String>(boxName);
  }

  Future<void> add(TransactionModel tx) async {
    final box = Hive.box<String>(boxName);
    final encrypted = await _encryption.encrypt(tx.toMap().toString());
    await box.put(tx.tid, encrypted);
  }

  Future<List<TransactionModel>> getAll() async {
    final box = Hive.box<String>(boxName);
    final List<TransactionModel> list = [];

    for (final key in box.keys) {
      final encrypted = box.get(key);
      if (encrypted == null) continue;

      final decrypted = await _encryption.decrypt(encrypted);
      final map = _parseMap(decrypted);
      list.add(TransactionModel.fromMap(map));
    }

    return list;
  }

  Future<List<TransactionModel>> filter(String query) async {
    final all = await getAll();
    final maps = all.map((e) => e.toMap()).toList();

    final filteredMaps = await _filter.filter(maps, query);
    return filteredMaps.map(TransactionModel.fromMap).toList();
  }

  /// Very small map parser (safe for simple key:value maps)
  Map<String, dynamic> _parseMap(String s) {
    try {
      final cleaned = s.trim();
      if (!cleaned.startsWith('{') || !cleaned.endsWith('}')) {
        return {};
      }

      final body = cleaned.substring(1, cleaned.length - 1);
      final entries = body.split(',');

      final map = <String, dynamic>{};
      for (final entry in entries) {
        final kv = entry.split(':');
        if (kv.length != 2) continue;
        map[kv[0].trim()] = kv[1].trim();
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}
