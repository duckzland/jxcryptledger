import 'package:hive_ce/hive.dart';

abstract class IpcAdapters {
  Map<String, TypeAdapter> get adapters => {};

  IpcAdapters();

  List<String> getKeys() {
    return adapters.keys.toList();
  }

  TypeAdapter get(String boxName) {
    final adapter = adapters[boxName];
    if (adapter == null) {
      throw StateError("No adapter registered for box '$boxName'");
    }
    return adapter;
  }

  void register() {}
}
