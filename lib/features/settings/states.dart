import 'dart:convert';
import '../../core/log.dart';
import 'controller.dart';
import 'keys.dart';

class StateService {
  SettingsController controller;

  StateService(this.controller);

  final Map<String, dynamic> _state = {};

  void init() {
    final jsonData = controller.get(SettingKey.states);
    if (jsonData != null) {
      populate(jsonData);
    }

    logln('Loaded app state from database.');
  }

  Future<void> save() async {
    final jsonData = store();

    await controller.update(SettingKey.states, jsonData);

    logln('Saved app state to database.');
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

  String store() {
    return jsonEncode(_state);
  }

  void populate(String jsonData) {
    final decoded = jsonDecode(jsonData);
    if (decoded is Map<String, dynamic>) {
      _state
        ..clear()
        ..addAll(decoded);
    }
  }
}
