import 'package:hive_ce/hive.dart';

import '../../../features/watchboard/panels/model.dart';
import '../../../features/watchers/model.dart';
import '../../../features/transactions/model.dart';
import '../../../system/settings/keys.dart';
import '../../../system/settings/service.dart';
import '../../log.dart';
import '../../mode.dart';
import '../locator.dart';

class MigratorDB {
  SettingsService get service => locator<SettingsService>();

  Future<void> execute() async {
    final currver = service.getByKey(SettingKey.migrateVersion, defaultValue: SettingKey.migrateVersion.defaultValue);
    switch (currver) {
      case "v1.1.0":
        final txBox = Hive.box<TransactionsModel>('transactions_box');
        final pxBox = Hive.box<PanelsModel>('panels_box');
        final wxBox = Hive.box<WatchersModel>('watchers_box');

        final Map<dynamic, TransactionsModel> txMap = Map.from(txBox.toMap());
        final Map<dynamic, PanelsModel> pxMap = Map.from(pxBox.toMap());
        final Map<dynamic, WatchersModel> wxMap = Map.from(wxBox.toMap());

        await txBox.clear();
        await pxBox.clear();
        await wxBox.clear();

        await txBox.putAll(txMap);
        await pxBox.putAll(pxMap);
        await wxBox.putAll(wxMap);

        await txBox.flush();
        await pxBox.flush();
        await wxBox.flush();

        CoreMode.dbVersion = "v1.2.0";

        await service.save(SettingKey.migrateVersion, CoreMode.dbVersion);

        logln("[MIGRATIONV1] Upgrading database to ${CoreMode.dbVersion}");
        break;
      default:
        break;
    }
  }
}
