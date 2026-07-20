import 'package:hive_ce/hive.dart';
import 'package:jxledger/features/archives/adapter.dart';
import 'package:jxledger/features/cryptos/adapter.dart';
import 'package:jxledger/features/rates/adapter.dart';
import 'package:jxledger/features/transactions/adapter.dart';
import 'package:jxledger/features/watchboard/panels/adapter.dart';
import 'package:jxledger/features/watchboard/tickers/adapter.dart';
import 'package:jxledger/features/watchers/adapter.dart';
import 'package:jxledger/ipc/database/adapters.dart';
import 'package:jxledger/system/settings/adapter.dart';

class AdaptersFaker extends IpcAdapters {
  AdaptersFaker();

  @override
  Map<String, TypeAdapter> get adapters => {
    'rates_box': RatesAdapter(),
    'cryptos_box': CryptosAdapter(),
    'settings_box': SettingsAdapter(),
    'watchers_box': WatchersAdapter(),
    'transactions_box': TransactionsAdapter(),
    'panels_box': PanelsAdapter(),
    'tickers_box': TickersAdapter(),
    'archives_box': ArchivesAdapter(),
  };

  @override
  void register() {}
}
