import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dotenv/dotenv.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxcryptledger/features/rates/adapter.dart';
import 'package:jxcryptledger/features/rates/model.dart';
import 'package:jxcryptledger/features/rates/repository.dart';

final env = DotEnv()..load();

String getAppDocumentsDir() {
  final dir = env['APP_DATA_DIR'];
  if (dir == null || dir.isEmpty) {
    throw Exception('APP_DATA_DIR not set in .env');
  }
  return dir;
}

Future<void> main() async {
  print("Seeding rates...");

  final dir = getAppDocumentsDir();
  Hive.init(dir);

  Hive.registerAdapter(RatesAdapter());

  final repo = RatesRepository();
  await repo.init();

  final coins = [
    {"id": 1, "symbol": "BTC"},
    {"id": 1027, "symbol": "ETH"},
    {"id": 825, "symbol": "USDT"},
    {"id": 1839, "symbol": "BNB"},
    {"id": 52, "symbol": "XRP"},
    {"id": 2010, "symbol": "ADA"},
    {"id": 74, "symbol": "DOGE"},
    {"id": 5426, "symbol": "SOL"},
    {"id": 6636, "symbol": "DOT"},
    {"id": 2, "symbol": "LTC"},
  ];

  for (final src in coins) {
    for (final tgt in coins) {
      if (src["id"] == tgt["id"]) continue;

      await repo.add(
        RatesModel(
          sourceSymbol: src["symbol"] as String,
          sourceId: src["id"] as int,
          sourceAmount: Decimal.parse("1"),
          targetSymbol: tgt["symbol"] as String,
          targetId: tgt["id"] as int,
          targetAmount: Decimal.parse("12345.${src["id"]}${tgt["id"]}987654321"),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  print("Done seeding.");
  exit(0);
}
