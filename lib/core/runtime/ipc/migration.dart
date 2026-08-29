import 'package:hive_ce/hive.dart';

import '../../../features/watchboard/markets/model.dart';
import '../../../features/watchboard/panels/model.dart';
import '../../../features/watchers/model.dart';
import '../../../features/transactions/model.dart';
import '../../../system/settings/keys.dart';
import '../../../system/settings/model.dart';
import '../../../ipc/abstracts/migration.dart';
import '../../log.dart';
import '../../mode.dart';

class CoreRuntimeIpcMigration extends IpcMigration {
  @override
  Future<void> migrateBeforeUnlock() async {
    // Nothing to migrate after v1.1.0
  }

  @override
  Future<void> migrateAfterUnlock() async {
    logln("Migrating database to ${CoreMode.dbVersion}", "MIGRATION");
    try {
      switch (CoreMode.dbVersion) {
        case "v1.1.0":
          final txBox = Hive.box<TransactionsModel>('transactions_box');
          final pxBox = Hive.box<PanelsModel>('panels_box');
          final wxBox = Hive.box<WatchersModel>('watchers_box');
          final mxBox = Hive.box<MarketsModel>('markets_box');
          final sxbox = Hive.box<SettingsModel>("settings_box");

          final Map<dynamic, TransactionsModel> txMap = Map.from(txBox.toMap());
          final Map<dynamic, PanelsModel> pxMap = Map.from(pxBox.toMap());
          final Map<dynamic, WatchersModel> wxMap = Map.from(wxBox.toMap());
          final Map<dynamic, MarketsModel> mxMap = Map.from(mxBox.toMap());

          await txBox.clear();
          await pxBox.clear();
          await wxBox.clear();
          await mxBox.clear();

          await txBox.putAll(txMap);
          await pxBox.putAll(pxMap);
          await wxBox.putAll(wxMap);
          await mxBox.putAll(mxMap);

          await txBox.flush();
          await pxBox.flush();
          await wxBox.flush();
          await mxBox.flush();

          await sxbox.put(
            SettingKey.migrateVersion.id,
            SettingsModel(keyId: SettingKey.migrateVersion.id, type: SettingKey.migrateVersion.type, value: "v1.2.0"),
          );

          CoreMode.dbVersion = "v1.2.0";

          logln("Upgrading database to ${CoreMode.dbVersion}", "MIGRATION");
          break;
        default:
          break;
      }
    } catch (e) {
      logln("Failed upgrading database to ${CoreMode.dbVersion}: $e", "MIGRATION");
    }
  }
}
