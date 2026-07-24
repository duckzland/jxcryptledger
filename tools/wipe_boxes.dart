import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxledger/core/log.dart' show logln;

final env = DotEnv()..load();

String getAppDocumentsDir() {
  final dir = env['APP_DATA_DIR'];
  if (dir == null || dir.isEmpty) {
    throw Exception('APP_DATA_DIR not set in .env');
  }
  return dir;
}

Future<void> main() async {
  logln("Wiping Hive boxes...");

  final dir = getAppDocumentsDir();
  Hive.init(dir);

  final boxes = [
    'settings_box',
    'transactions_box',
    'cryptos_box',
    'rates_box',
    'watchers_box',
    'panels_box',
    'tickers_box',
    'archives_box',
  ];

  for (final boxName in boxes) {
    try {
      await Hive.deleteBoxFromDisk(boxName);
      logln("Deleted box: $boxName");
    } catch (e) {
      logln("Failed to delete $boxName: $e");
    }
  }

  logln("Done.");
  exit(0);
}
