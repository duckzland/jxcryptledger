import 'dart:convert';
import 'dart:isolate';

import '../../abstracts/models/with_id.dart';
import '../../abstracts/models/exportable.dart';
import '../../abstracts/repository.dart';

mixin CoreMixinsRepositoriesExportable<T extends CoreModelWithId> on CoreBaseRepository<T> {
  T Function(Map<String, dynamic> json) get fromJson;

  Future<String> export() async {
    final snapshot = extract().cast<CoreModelExportable>().toList();
    return Isolate.run(() {
      final jsonList = snapshot.map((e) => e.toJson()).toList();
      return jsonEncode(jsonList);
    });
  }

  Future<void> import(String rawJson) async {
    final parser = fromJson;

    final items = await Isolate.run(() {
      final decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded.map((e) => parser(e as Map<String, dynamic>)).toList();
    });

    await box.replace(items);
  }
}
