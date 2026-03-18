import 'dart:convert';

import '../abstracts/model.dart';
import '../abstracts/repository.dart';

mixin CoreMixinsExportable<T extends CoreBaseModel<K>, K> on CoreBaseRepository<T, K> {
  T Function(Map<String, dynamic> json) get fromJson;

  Future<String> export() async {
    final items = await getAll();
    final jsonList = items.map((e) => e.toJson()).toList();
    return jsonEncode(jsonList);
  }

  Future<void> import(String rawJson) async {
    final decoded = jsonDecode(rawJson) as List<dynamic>;
    final txs = decoded.map((e) => fromJson(e as Map<String, dynamic>)).toList();

    await box.clear();
    for (final tx in txs) {
      await box.put(tx.uuid, tx);
    }
  }
}
