import 'package:hive/hive.dart';
import 'model.dart';
import '../../core/encryption_service.dart';
import '../../core/filter_isolate.dart';

class SettingsRepository {
  static const String boxName = 'settings_box';

  final EncryptionService _encryption = EncryptionService.instance;
  final FilterIsolate _filter = FilterIsolate();

  Future<void> init() async {
    await _filter.init();
    await Hive.openBox<String>(boxName);
  }

  Future<void> save(SettingsModel settings) async {
    final box = Hive.box<String>(boxName);
    final encrypted = await _encryption.encrypt(settings.toMap().toString());
    await box.put('settings', encrypted);
  }

  Future<SettingsModel?> load() async {
    final box = Hive.box<String>(boxName);
    final encrypted = box.get('settings');
    if (encrypted == null) return null;

    final decrypted = await _encryption.decrypt(encrypted);
    final map = _parseMap(decrypted);
    return SettingsModel.fromMap(map);
  }

  Future<SettingsModel?> filter(String query) async {
    final settings = await load();
    if (settings == null) return null;

    final filtered = await _filter.filter([settings.toMap()], query);
    if (filtered.isEmpty) return null;

    return SettingsModel.fromMap(filtered.first);
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
