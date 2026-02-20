import 'dart:io';
import 'package:hive_ce/hive_ce.dart';
import 'package:decimal/decimal.dart';

import 'package:jxcryptledger/features/rates/model.dart';
import 'package:jxcryptledger/features/rates/repository.dart';
import 'package:jxcryptledger/features/rates/adapter.dart';

String getAppDocumentsDir() {
  // 1. Try XDG_DOCUMENTS_DIR (Linux standard)
  final xdgDocs = Platform.environment['XDG_DOCUMENTS_DIR'];
  if (xdgDocs != null && xdgDocs.isNotEmpty) {
    return xdgDocs;
  }

  // 2. Fallback: $HOME/Documents (Flutter's fallback)
  final home = Platform.environment['HOME'];
  if (home != null && home.isNotEmpty) {
    return '$home/Documents';
  }

  throw Exception('Cannot determine application documents directory');
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
          targetAmount: Decimal.parse(
            "12345.${src["id"]}${tgt["id"]}987654321",
          ),
        ),
      );
    }
  }

  print("Done seeding.");
  exit(0);
}
