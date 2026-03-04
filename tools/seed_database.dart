import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dotenv/dotenv.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxcryptledger/features/cryptos/adapter.dart';
import 'package:jxcryptledger/features/cryptos/model.dart';
import 'package:jxcryptledger/features/cryptos/parser.dart';
import 'package:jxcryptledger/features/rates/adapter.dart';
import 'package:jxcryptledger/features/transactions/adapter.dart';
import 'package:jxcryptledger/features/transactions/model.dart';
import 'package:jxcryptledger/features/transactions/repository.dart';

final env = DotEnv()..load();
final txRepo = TransactionsRepository();
final AesGcm aes = AesGcm.with256bits();

final List<int> staticCmcIds = [1, 2, 52, 1831, 2010, 6636, 5426, 5805, 3890, 1975, 512, 1958, 1321, 328, 3794];

int pickCmcId(int index) => staticCmcIds[index % staticCmcIds.length];

Future<bool> fetchCryptos({required String endpoint, required Box<CryptosModel> cryptosBox}) async {
  try {
    final client = HttpClient();
    final uri = Uri.parse(endpoint);

    final request = await client.getUrl(uri);
    request.headers.set('Accept', 'application/json');

    final response = await request.close();

    if (response.statusCode != 200) {
      print("Failed to fetch cryptos: HTTP ${response.statusCode}");
      return false;
    }

    final body = await response.transform(utf8.decoder).join();
    final parsed = cryptosParser({"body": body});

    if (parsed.isEmpty) {
      print("Failed to fetch cryptos: empty parsed list");
      return false;
    }

    await cryptosBox.clear();

    for (final m in parsed) {
      cryptosBox.add(CryptosModel(id: m["id"], name: m["name"], symbol: m["symbol"], status: m["status"], active: m["active"]));
    }

    await cryptosBox.flush();
    print("Fetching cryptos completed");
    return true;
  } catch (e) {
    print("Failed to fetch cryptos: $e");
    return false;
  }
}

Future<String> encryptValue(String plainText, Uint8List keyBytes) async {
  final secretKey = SecretKey(keyBytes);
  final nonce = aes.newNonce();
  final secretBox = await aes.encrypt(utf8.encode(plainText), secretKey: secretKey, nonce: nonce);

  final combined = <int>[...nonce, ...secretBox.cipherText, ...secretBox.mac.bytes];

  return base64Encode(combined);
}

String requireEnv(String key) {
  final v = env[key];
  if (v == null || v.isEmpty) {
    throw Exception("$key not set in .env");
  }
  return v.replaceAll('\uFEFF', '').trim();
}

Future<Uint8List> derivePasswordKey(String password, String salt) async {
  final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);

  final secretKey = await pbkdf2.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: utf8.encode(salt));

  return Uint8List.fromList(await secretKey.extractBytes());
}

Future<TransactionsModel> createChild(
  String label,
  TransactionsRepository repo,
  TransactionsModel parent,
  double srAmount,
  int rrId,
) async {
  final tid = repo.generateTid();
  final rrAmount = srAmount * 2;

  if (parent.rrId == rrId) {
    rrId += 1;
  }

  final tx = TransactionsModel(
    tid: tid,
    pid: parent.tid,
    rid: parent.isRoot ? parent.tid : parent.rid,
    srAmount: srAmount,
    srId: parent.rrId,
    rrAmount: rrAmount,
    rrId: rrId,
    balance: rrAmount,
    status: TransactionStatus.active.index,
    closable: false,
    timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
    meta: {},
  );
  print("Generating Leaf $label: ${tx.tid}");
  await repo.add(tx);

  return tx;
}

Future<void> main(List<String> args) async {
  final bool noArgs = args.isEmpty;

  final bool seedTx = noArgs ? true : args.contains('--seed-transactions');

  final bool seedCryptos = noArgs ? true : args.contains('--seed-cryptos');

  final dir = requireEnv('APP_DATA_DIR');
  final password = requireEnv('APP_DB_PASSWORD');

  print("Initializing Hives...");
  Hive.init(dir);

  Hive.registerAdapter(TransactionsAdapter());
  Hive.registerAdapter(RatesAdapter());
  Hive.registerAdapter(CryptosAdapter());

  print("Wiping old boxes...");
  final boxes = ['settings_box', 'rates_box'];

  if (seedTx) {
    boxes.add('transactions_box');
  }

  if (seedCryptos) {
    boxes.add('cryptos_box');
  }

  for (final box in boxes) {
    try {
      await Hive.deleteBoxFromDisk(box);
      print("Deleted: $box");
    } catch (e) {
      print("Failed to delete $box: $e");
    }
  }

  print("Preparing for encryption..");
  final salt = env['APP_SALT'] ?? '7f8a2c1e9d3b4f5a6b8b9c0d1e2f3a4b5c6d7e8f9a7c8d9e0f1a2b3c4d5e6f7a';
  final key = await derivePasswordKey(password, salt);
  final cipher = HiveAesCipher(key);

  print("Seeding settings...");
  final settingsBox = await Hive.openBox('settings_box', encryptionCipher: cipher, crashRecovery: false);
  final encryptedMarker = await encryptValue("initialized", key);
  await settingsBox.put('vaultInitialized', encryptedMarker);

  if (seedCryptos) {
    print("Seeding cryptos...");
    final cryptosBox = await Hive.openBox<CryptosModel>('cryptos_box');
    await fetchCryptos(endpoint: requireEnv('CMC_ENDPOINT'), cryptosBox: cryptosBox);
  }

  if (seedTx) {
    print("Seeding transactions...");
    await Hive.openBox<TransactionsModel>('transactions_box', encryptionCipher: cipher, crashRecovery: false);
    final txRepo = TransactionsRepository();
    await txRepo.init();

    final List<TransactionsModel> roots = [];

    for (int r = 0; r < 3; r++) {
      final rootTid = txRepo.generateTid();
      final root = TransactionsModel(
        tid: rootTid,
        pid: '0',
        rid: '0',
        srAmount: 1000,
        srId: pickCmcId(r),
        rrAmount: 100000,
        rrId: pickCmcId(r + 1),
        balance: 100000,
        status: TransactionStatus.active.index,
        closable: true,
        timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
        meta: {"rootIndex": r},
      );
      print("Generating Root: ${root.tid}");
      await txRepo.add(root);
      roots.add(root);
    }

    for (final root in roots) {
      // Branch A
      final A = await createChild("A", txRepo, root, root.balance * 0.5, pickCmcId(10));
      final A1 = await createChild("A1", txRepo, A, A.balance / 2, pickCmcId(11));
      final A11 = await createChild("A11", txRepo, A1, A1.balance / 2, pickCmcId(12));
      final A12 = await createChild("A12", txRepo, A1, A1.balance / 2, pickCmcId(13));

      final A2 = await createChild("A2", txRepo, A, A.balance / 2, pickCmcId(14));
      final A21 = await createChild("A21", txRepo, A2, A2.balance / 3, pickCmcId(15));

      // Branch B
      final B = await createChild("B", txRepo, root, root.balance * 0.25, pickCmcId(16));
      final B1 = await createChild("B1", txRepo, B, B.balance / 2, pickCmcId(17));
      final B2 = await createChild("B2", txRepo, B, B.balance / 2, B.srId);

      // Branch C
      final C = await createChild("C", txRepo, root, root.balance * 0.25, pickCmcId(19));
      final C1 = await createChild("C1", txRepo, C, C.balance / 2, C.srId);
      final C2 = await createChild("C2", txRepo, C, C.balance / 2, root.rrId);

      // Test Close
      // print("Closing: C1");
      // await txRepo.close(C1);

      // print("Closing: C2");
      // await txRepo.close(C2);

      // Test decreasing amount
      // print("Decreasing: B2 balance");
      // final B2Decrease = B2.copyWith(srAmount: B2.balance / 4);
      // await txRepo.update(B2Decrease);
    }
  }

  // print("Seeding rates");
  // await Hive.openBox<RatesModel>('rates_box');

  print("Vault seeded successfully.");
  await Hive.close();
  exit(0);
}
