import 'package:hive_ce/hive_ce.dart';

import '../../core/filtering.dart';
import '../encryption/service.dart';
import 'model.dart';

class TransactionsRepository {
  static const String boxName = 'transactions_box';

  final EncryptionService _encryption = EncryptionService.instance;
  final FilterIsolate _filter = FilterIsolate();

  Future<void> init() async {
    await _filter.init();
    await Hive.openBox<String>(boxName);
  }

  Future<void> add(TransactionsModel tx) async {
    final box = Hive.box<String>(boxName);
    final encrypted = await _encryption.encrypt(tx.toMap().toString());
    await box.put(tx.tid, encrypted);
  }

  Future<List<TransactionsModel>> getAll() async {
    final box = Hive.box<String>(boxName);
    final List<TransactionsModel> list = [];

    for (final key in box.keys) {
      final encrypted = box.get(key);
      if (encrypted == null) continue;

      final decrypted = await _encryption.decrypt(encrypted);
      final map = _parseMap(decrypted);
      list.add(TransactionsModel.fromMap(map));
    }

    return list;
  }

  Future<List<TransactionsModel>> filter(String query) async {
    final all = await getAll();
    final maps = all.map((e) => e.toMap()).toList();

    final filteredMaps = await _filter.filter(maps, query);
    return filteredMaps.map(TransactionsModel.fromMap).toList();
  }

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
