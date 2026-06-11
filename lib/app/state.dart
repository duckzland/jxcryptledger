import 'dart:convert';

import '../core/log.dart';

class AppState {
  AppState._internal();

  static final AppState instance = AppState._internal();

  final Map<String, dynamic> _state = {};

  void load() {
    logln('Loading settings from DB...');
  }

  void save() {
    final jsonData = store();
    logln('Saving settings to DB: $jsonData');
  }

  dynamic get(String key, {dynamic defaultValue}) {
    return key.isNotEmpty && _state.containsKey(key) ? _state[key] : defaultValue;
  }

  void set(String key, dynamic value) {
    _state[key] = value;
  }

  void remove(String key) {
    _state.remove(key);
  }

  void removeByPrefix(String prefix) {
    if (prefix.isEmpty) return;
    final keysToRemove = _state.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      _state.remove(key);
    }
  }

  String store() => jsonEncode(_state);

  void populate(String jsonData) {
    final decoded = jsonDecode(jsonData);
    if (decoded is Map<String, dynamic>) {
      _state
        ..clear()
        ..addAll(decoded);
    }
  }
}
