import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxcryptledger/features/transactions/adapter.dart';
import 'package:jxcryptledger/features/transactions/model.dart';
import 'package:jxcryptledger/features/transactions/repository.dart';
import 'package:uuid/uuid.dart';

final env = DotEnv()..load();
final uuid = Uuid();

String getAppDocumentsDir() {
  final dir = env['APP_DATA_DIR'];
  if (dir == null || dir.isEmpty) {
    throw Exception('APP_DATA_DIR not set in .env');
  }
  return dir;
}

Future<void> main() async {
  print("Seeding transactions...");

  final dir = getAppDocumentsDir();
  final password = env['APP_DB_PASSWORD'];
  if (password == null || password.isEmpty) {
    throw Exception('APP_DB_PASSWORD not set in .env');
  }

  Hive.init(dir);
  Hive.registerAdapter(TransactionsAdapter());

  final repo = TransactionsRepository();
  await repo.init(password: password);

  // Root transaction
  final rootTid = uuid.v4();
  final root = TransactionsModel(
    tid: rootTid,
    pid: '0',
    rid: '0',
    srAmount: 0,
    srId: 1,
    rrAmount: 0,
    rrId: 1,
    balance: 0,
    status: TransactionStatus.active.index,
    closable: false,
    timestamp: DateTime.now().millisecondsSinceEpoch,
    meta: {},
  );
  await repo.add(root);

  // Generate 30 transactions with mixed statuses
  for (int i = 0; i < 30; i++) {
    final tid = uuid.v4();
    final parentTid = (i % 5 == 0) ? rootTid : uuid.v4(); // some attach to root, some to other nodes

    final status = (i % 4 == 0)
        ? TransactionStatus.active.index
        : (i % 4 == 1)
        ? TransactionStatus.partial.index
        : (i % 4 == 2)
        ? TransactionStatus.inactive.index
        : TransactionStatus.closed.index;

    final tx = TransactionsModel(
      tid: tid,
      pid: parentTid,
      rid: rootTid,
      srAmount: (i + 1) * 10.0,
      srId: 1000 + i,
      rrAmount: (i + 1) * 20.0,
      rrId: 2000 + i,
      balance: (i + 1) * 100.0,
      status: status,
      closable: status == TransactionStatus.closed.index,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      meta: {"seedIndex": i},
    );

    await repo.add(tx);
  }

  print("Done seeding transactions.");
  exit(0);
}
