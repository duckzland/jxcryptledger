import 'package:hive_ce/hive.dart';

import '../../../features/archives/adapter.dart';
import '../../../features/archives/model.dart';
import '../../../features/cryptos/adapter.dart';
import '../../../features/cryptos/model.dart';
import '../../../features/rates/adapter.dart';
import '../../../features/rates/model.dart';
import '../../../features/transactions/adapter.dart';
import '../../../features/transactions/model.dart';
import '../../../features/watchboard/panels/adapter.dart';
import '../../../features/watchboard/panels/model.dart';
import '../../../features/watchboard/tickers/adapter.dart';
import '../../../features/watchboard/tickers/model.dart';
import '../../../features/watchers/adapter.dart';
import '../../../features/watchers/model.dart';
import '../../../system/settings/adapter.dart';
import '../../../system/settings/model.dart';

class CoreIpcAdapters {
  final Map<String, TypeAdapter> adapters = {
    'rates_box': RatesAdapter(),
    'cryptos_box': CryptosAdapter(),
    'settings_box': SettingsAdapter(),
    'watchers_box': WatchersAdapter(),
    'transactions_box': TransactionsAdapter(),
    'panels_box': PanelsAdapter(),
    'tickers_box': TickersAdapter(),
    'archives_box': ArchivesAdapter(),
  };

  CoreIpcAdapters();

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

  void register() {
    Hive.registerAdapter<TransactionsModel>(TransactionsAdapter());
    Hive.registerAdapter<CryptosModel>(CryptosAdapter());
    Hive.registerAdapter<RatesModel>(RatesAdapter());
    Hive.registerAdapter<WatchersModel>(WatchersAdapter());
    Hive.registerAdapter<PanelsModel>(PanelsAdapter());
    Hive.registerAdapter<TickersModel>(TickersAdapter());
    Hive.registerAdapter<ArchivesModel>(ArchivesAdapter());
    Hive.registerAdapter<SettingsModel>(SettingsAdapter());
  }
}
