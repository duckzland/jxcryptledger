import 'dart:convert';
import '../core/locator.dart';
import '../core/log.dart';
import '../features/settings/controller.dart';
import '../features/settings/keys.dart';
import '../features/tools/page.dart';
import '../features/transactions/page.dart';

class AppState {
  AppState._internal();

  static final AppState instance = AppState._internal();
  SettingsController get controller => locator<SettingsController>();

  final Map<String, dynamic> _state = {};

  void load() {
    final jsonData = controller.get(SettingKey.appState);
    if (jsonData != null) {
      populate(jsonData);
    }

    logln('Loaded app state from database.');
  }

  Future<void> save() async {
    final jsonData = store();

    await controller.update(SettingKey.appState, jsonData);

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
    return jsonEncode(
      _state,
      toEncodable: (Object? object) {
        if (object is Enum) {
          return {'__isEnum__': true, 'enumType': object.runtimeType.toString(), 'enumValue': object.name};
        }
        throw Exception('Unsupported type for JSON serialization: ${object.runtimeType}');
      },
    );
  }

  void populate(String jsonData) {
    final decoded = jsonDecode(jsonData);
    if (decoded is Map<String, dynamic>) {
      _state.clear();

      decoded.forEach((key, value) {
        _state[key] = _restoreCustomTypes(value);
      });
    }
  }

  dynamic _restoreCustomTypes(dynamic value) {
    if (value is Map<String, dynamic>) {
      if (value['__isEnum__'] == true) {
        final String type = value['enumType'];
        final String name = value['enumValue'];

        return _resolveEnumByName(type, name);
      }
      return value.map((k, v) => MapEntry(k, _restoreCustomTypes(v)));
    } else if (value is List) {
      return value.map(_restoreCustomTypes).toList();
    }
    return value;
  }

  dynamic _resolveEnumByName(String type, String name) {
    switch (type) {
      case 'SettingKey':
        return SettingKey.values.byName(name);

      case 'ToolsViewMode':
        return ToolsViewMode.values.byName(name);

      case 'TransactionsViewMode':
        return TransactionsViewMode.values.byName(name);

      default:
        throw Exception('Unknown enum type: $type');
    }
  }
}
