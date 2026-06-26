import 'package:hive_ce/hive_ce.dart';

class CoreIpcRegistry {
  static final Map<String, TypeAdapter> boxAdapters = {};
  static final Map<String, Box> boxInstances = {};

  static void registerAdapter(String boxName, TypeAdapter adapter) {
    boxAdapters[boxName] = adapter;
  }

  static void registerBox(String boxName, Box box) {
    boxInstances[boxName] = box;
  }

  static TypeAdapter getAdapter(String boxName) {
    final adapter = boxAdapters[boxName];
    if (adapter == null) {
      throw StateError("No adapter registered for box '$boxName'");
    }
    return adapter;
  }

  static Box getBox(String boxName) {
    final box = boxInstances[boxName];
    if (box == null) {
      throw StateError("No box instance registered for '$boxName'");
    }
    return box;
  }
}
