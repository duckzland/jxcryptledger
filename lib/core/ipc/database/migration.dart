import 'package:hive_ce/hive_ce.dart';

import '../../../app/constants.dart';
import '../../../system/settings/model.dart';
import '../../../features/watchboard/tickers/service.dart';
import '../../runtime/locator.dart';

class CoreIpcMigration {
  final TickersService _tickersService = locator<TickersService>();

  Future<void> migrate() async {
    await _migrateSettingsBox();

    if (isVersionLessThan(appVersion, "1.3.0.0")) {
      final tickers = _tickersService.extract();
      final exists = tickers.any((ticker) => ticker.tid == "market_cap");
      if (!exists) {
        await _tickersService.clear();
        await _tickersService.populate();
      }
    }
  }

  Future<void> _migrateSettingsBox() async {
    if (!Hive.isBoxOpen('settings_box')) {
      return;
    }

    final box = Hive.box<dynamic>('settings_box');
    final entries = Map<dynamic, dynamic>.from(box.toMap());

    for (final entry in entries.entries) {
      final dynamic rawValue = entry.value;
      if (rawValue is SettingsModel) {
        continue;
      }

      final String keyId = entry.key.toString();
      final dynamic legacyValue = rawValue is Map && rawValue.isNotEmpty ? rawValue[keyId] ?? rawValue.values.first : rawValue;
      final model = SettingsModel.fromLegacy(keyId, legacyValue);
      await box.put(keyId, model);
    }

    await box.flush();
  }

  bool isVersionLessThan(String current, String target) {
    final currentParts = current.split('.').map(int.parse).toList();
    final targetParts = target.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length; i++) {
      if (currentParts[i] < targetParts[i]) return true;
      if (currentParts[i] > targetParts[i]) return false;
    }
    return false;
  }
}
