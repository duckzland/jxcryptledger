import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:hive_ce/hive_ce.dart';

final env = DotEnv()..load();

String getAppDocumentsDir() {
  final dir = env['APP_DATA_DIR'];
  if (dir == null || dir.isEmpty) {
    throw Exception('APP_DATA_DIR not set in .env');
  }
  return dir;
}

Future<void> main() async {
  print("Wiping Hive boxes...");

  final dir = getAppDocumentsDir();
  Hive.init(dir);

  final boxes = [
    'settings_box',
    'transactions_box',
    // 'cryptos_box',
    'rates_box',
  ];

  for (final boxName in boxes) {
    try {
      await Hive.deleteBoxFromDisk(boxName);
      print("Deleted box: $boxName");
    } catch (e) {
      print("Failed to delete $boxName: $e");
    }
  }

  print("Done.");
  exit(0);
}
