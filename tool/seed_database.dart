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
import 'package:jxcryptledger/features/rates/model.dart';
import 'package:jxcryptledger/features/transactions/adapter.dart';
import 'package:jxcryptledger/features/transactions/model.dart';
import 'package:uuid/uuid.dart';

final env = DotEnv()..load();
final uuid = Uuid();

final AesGcm aes = AesGcm.with256bits();

// REAL, VALID CoinMarketCap IDs
final List<int> staticCmcIds = [
  1, // BTC
  2, // LTC
  52, // XRP
  1831, // BCH
  2010, // ADA
  6636, // DOT
  5426, // SOL
  5805, // AVAX
  3890, // MATIC
  1975, // LINK
  512, // XLM
  1958, // TRX
  1321, // ETC
  328, // XMR
  3794, // ATOM
];

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
      cryptosBox.add(
        CryptosModel(id: m["id"], name: m["name"], symbol: m["symbol"], status: m["status"], active: m["active"]),
      );
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

  final nonce = aes.newNonce(); // 12 bytes
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

  final bytes = await secretKey.extractBytes();
  return Uint8List.fromList(bytes);
}

Future<void> main() async {
  final dir = requireEnv('APP_DATA_DIR');
  final password = requireEnv('APP_DB_PASSWORD');

  print("Initializing Hives...");
  Hive.init(dir);

  Hive.registerAdapter(TransactionsAdapter());
  Hive.registerAdapter(RatesAdapter());
  Hive.registerAdapter(CryptosAdapter());

  print("Wiping old boxes...");
  final boxes = ['settings_box', 'transactions_box', 'cryptos_box', 'rates_box'];

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

  print("Seeding cryptos...");
  final cryptosBox = await Hive.openBox<CryptosModel>('cryptos_box');
  await fetchCryptos(endpoint: requireEnv('CMC_ENDPOINT'), cryptosBox: cryptosBox);

  print("Seeding transactions...");
  final txBox = await Hive.openBox<TransactionsModel>(
    'transactions_box',
    encryptionCipher: cipher,
    crashRecovery: false,
  );

  final rootTid = uuid.v4();
  final root = TransactionsModel(
    tid: rootTid,
    pid: '0',
    rid: '0',
    srAmount: 0,
    srId: pickCmcId(0),
    rrAmount: 0,
    rrId: pickCmcId(1),
    balance: 0,
    status: TransactionStatus.active.index,
    closable: false,
    timestamp: DateTime.now().millisecondsSinceEpoch,
    meta: {},
  );

  await txBox.put(rootTid, root);

  for (int i = 0; i < 30; i++) {
    final tid = uuid.v4();
    final parentTid = (i % 5 == 0) ? rootTid : uuid.v4();

    final status = switch (i % 4) {
      0 => TransactionStatus.active.index,
      1 => TransactionStatus.partial.index,
      2 => TransactionStatus.inactive.index,
      _ => TransactionStatus.closed.index,
    };

    final tx = TransactionsModel(
      tid: tid,
      pid: parentTid,
      rid: rootTid,
      srAmount: (i + 1) * 10.0,
      srId: pickCmcId(i),
      rrAmount: (i + 1) * 20.0,
      rrId: pickCmcId(i + 1),
      balance: (i + 1) * 100.0,
      status: status,
      closable: status == TransactionStatus.closed.index,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      meta: {"seedIndex": i},
    );

    await txBox.put(tid, tx);
  }

  print("Seeding rates");
  await Hive.openBox<RatesModel>('rates_box');
  // @TODO calculate the rates needed from transactions and seed it

  print("Vault seeded successfully.");
  await Hive.close();
  exit(0);
}
