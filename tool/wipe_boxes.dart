import 'dart:io';
import 'package:hive_ce/hive_ce.dart';

String getAppDocumentsDir() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

  if (Platform.isMacOS) {
    return '$home/Library/Application Support/jxcryptledger';
  }

  if (Platform.isLinux) {
    return '$home/.local/share/jxcryptledger';
  }

  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA']!;
    return '$appData\\jxcryptledger';
  }

  throw UnsupportedError("Unsupported platform for standalone script");
}

Future<void> main() async {
  print("Wiping Hive boxes...");

  final dir = getAppDocumentsDir();
  Hive.init(dir);

  final boxes = [
    'settings_box',
    'transactions_box',
    'cryptos_box',
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
