import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:decimal/decimal.dart';
import 'package:dotenv/dotenv.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxledger/core/abstracts/models/exportable.dart';
import 'package:jxledger/core/log.dart';
import 'package:jxledger/core/math.dart';
import 'package:jxledger/features/archives/adapter.dart';
import 'package:jxledger/features/archives/model.dart';
import 'package:jxledger/features/cryptos/adapter.dart';
import 'package:jxledger/features/cryptos/model.dart';
import 'package:jxledger/features/cryptos/parsers/legacy.dart';
import 'package:jxledger/features/rates/adapter.dart';
import 'package:jxledger/features/rates/model.dart';
import 'package:jxledger/system/settings/adapter.dart';
import 'package:jxledger/system/settings/keys.dart';
import 'package:jxledger/system/settings/model.dart';
import 'package:jxledger/features/transactions/adapter.dart';
import 'package:jxledger/features/transactions/model.dart';
import 'package:jxledger/features/watchboard/panels/adapter.dart';
import 'package:jxledger/features/watchboard/panels/model.dart';
import 'package:jxledger/features/watchboard/tickers/adapter.dart';
import 'package:jxledger/features/watchers/adapter.dart';
import 'package:jxledger/features/watchers/model.dart';

final env = DotEnv()..load();
final AesGcm aes = AesGcm.with256bits();
final String latestDB = "v1.2.0";
const int defaultTransactionCount = 40;
const int defaultTransactionDepth = 8;

final List<int> staticCmcIds = [1, 2, 52, 1831, 2010, 6636, 5426, 5805, 20947, 1975, 512, 1958, 1321, 328, 3794];
final Map<int, String> staticCmcSymbol = {
  1: "BTC",
  2: "LTC",
  52: "XRP",
  1831: "BCH",
  2010: "ADA",
  6636: "DOT",
  5426: "SOL",
  5805: "AVAX",
  20947: "SUI",
  1975: "LINK",
  512: "XLM",
  1958: "TRX",
  1321: "ETC",
  328: "XMR",
  3794: "ATOM",
};

int pickCmcId(int index) => staticCmcIds[index % staticCmcIds.length];

String pickCmcSymbol(int index) => staticCmcSymbol[index] ?? "UNK";

Future<bool> fetchCryptos({required String endpoint, required Box<CryptosModel> cryptosBox}) async {
  try {
    final client = HttpClient();
    final uri = Uri.parse(endpoint);

    final request = await client.getUrl(uri);
    request.headers.set('Accept', 'application/json');

    final response = await request.close();

    if (response.statusCode != 200) {
      logln("Failed to fetch cryptos: HTTP ${response.statusCode}", "TOOLS");
      return false;
    }

    final body = await response.transform(utf8.decoder).join();
    final parsed = cryptosParsersLegacy({"body": body});

    if (parsed.isEmpty) {
      logln("Failed to fetch cryptos: empty parsed list", "TOOLS");
      return false;
    }

    await cryptosBox.clear();

    for (final m in parsed) {
      cryptosBox.add(CryptosModel(id: m["id"], name: m["name"], symbol: m["symbol"], status: m["status"], active: m["active"]));
    }

    await cryptosBox.flush();
    logln("Fetching cryptos completed", "TOOLS");
    return true;
  } catch (e) {
    logln("Failed to fetch cryptos: $e", "TOOLS");
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

String generateId() {
  final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random();

  while (true) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final timePart = now.toRadixString(36).padLeft(4, '0');
    final timeSuffix = timePart.substring(timePart.length - 4);
    final randomPart = String.fromCharCodes(Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

    return '$timeSuffix$randomPart';
  }
}

Future<String> export<T>(Box box) async {
  final items = box.values.toList();
  final jsonList = items.cast<T>().map((e) => (e as CoreModelExportable).toJson()).toList();
  return jsonEncode(jsonList);
}

int? parseOption(List<String> args, String name) {
  final prefix = '$name=';
  final argIndex = args.indexWhere((arg) => arg == name || arg.startsWith(prefix));
  if (argIndex == -1) return null;

  final value = args[argIndex] == name ? (argIndex + 1 < args.length ? args[argIndex + 1] : null) : args[argIndex].substring(prefix.length);
  final parsed = value == null ? null : int.tryParse(value);
  if (parsed == null || parsed < 0) {
    throw ArgumentError('Use $name=<non-negative integer>.');
  }
  return parsed;
}

Future<void> generateTransactions(Box<TransactionsModel> txRepo, int count, int depth) async {
  const batchSize = 1000;
  final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
  var batch = <String, TransactionsModel>{};
  var index = 0;

  Future<void> flushBatch() async {
    if (batch.isEmpty) return;
    await txRepo.putAll(batch);
    batch = <String, TransactionsModel>{};
  }

  while (index < count) {
    final rootIndex = index;
    final rootId = 'edge${rootIndex.toString().padLeft(8, '0')}';
    final rootRrId = pickCmcId(rootIndex + 1);
    var parent = TransactionsModel(
      tid: rootId,
      pid: '0',
      rid: '0',
      srAmount: Decimal.fromInt(1000),
      srId: pickCmcId(rootIndex),
      rrAmount: Decimal.fromInt(100000),
      rrId: rootRrId,
      balance: Decimal.fromInt(100000),
      status: TransactionStatus.active.index,
      closable: true,
      timestamp: timestamp - rootIndex * Duration(minutes: 1).inMicroseconds,
      meta: {'stressIndex': rootIndex, 'stressDepth': 0},
    );
    batch[parent.tid] = parent;
    index++;

    for (var level = 1; level <= depth && index < count; level++) {
      final tid = 'edge${index.toString().padLeft(8, '0')}';
      final rrId = pickCmcId(parent.rrId == staticCmcIds.last ? 0 : staticCmcIds.indexOf(parent.rrId) + 1);
      final child = TransactionsModel(
        tid: tid,
        pid: parent.tid,
        rid: rootId,
        srAmount: Decimal.one,
        srId: parent.rrId,
        rrAmount: Decimal.fromInt(2),
        rrId: rrId,
        balance: Decimal.fromInt(2),
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: timestamp - index * Duration(minutes: 1).inMicroseconds,
        meta: {'stressIndex': index, 'stressDepth': level},
      );
      parent = parent.copyWith(balance: parent.balance - Decimal.one, status: TransactionStatus.partial.index);
      batch[parent.tid] = parent;
      batch[child.tid] = child;
      index++;

      if (batch.length >= batchSize) {
        await flushBatch();
      }
    }

    if (batch.length >= batchSize) {
      await flushBatch();
    }
  }

  await flushBatch();
}

Future<void> main(List<String> args) async {
  final bool noArgs = args.isEmpty;
  final transactionCount = parseOption(args, '--transaction-count') ?? defaultTransactionCount;
  final transactionDepth = parseOption(args, '--transaction-depth') ?? defaultTransactionDepth;
  final panelCount = parseOption(args, '--panel-count');

  final bool seedTx = noArgs ? true : args.contains('--seed-transactions') || args.any((arg) => arg.startsWith('--transaction-count'));

  final bool seedCryptos = noArgs ? true : args.contains('--seed-cryptos');

  final bool seedPanels = noArgs ? true : args.contains('--seed-panels') || args.any((arg) => arg.startsWith('--panel-count'));

  final bool seedRates = noArgs ? true : args.contains('--seed-rates');

  final bool seedWatchers = noArgs ? true : args.contains('--seed-watchers');

  final bool seedArchives = noArgs ? true : args.contains('--seed-archives');

  final bool useEnvSalt = noArgs ? false : args.contains('--use-env-salt');

  final dir = requireEnv('APP_DATA_DIR');
  final password = requireEnv('APP_DB_PASSWORD');

  logln("Initializing Hives...", "TOOLS");
  Hive.init(dir);

  Hive.registerAdapter(TransactionsAdapter());
  Hive.registerAdapter(RatesAdapter());
  Hive.registerAdapter(CryptosAdapter());
  Hive.registerAdapter(WatchersAdapter());
  Hive.registerAdapter(PanelsAdapter());
  Hive.registerAdapter(TickersAdapter());
  Hive.registerAdapter(ArchivesAdapter());

  logln("Wiping old boxes...", "TOOLS");
  final boxes = ['settings_box'];

  if (seedTx) {
    boxes.add('transactions_box');
  }

  if (seedCryptos) {
    boxes.add('cryptos_box');
  }

  if (seedRates) {
    boxes.add('rates_box');
  }

  if (seedPanels) {
    boxes.add('panels_box');
  }

  if (seedWatchers) {
    boxes.add('watchers_box');
  }

  if (seedArchives) {
    boxes.add('archives_box');
  }

  for (final box in boxes) {
    try {
      await Hive.deleteBoxFromDisk(box);
      logln("Deleted: $box", "TOOLS");
    } catch (e) {
      logln("Failed to delete $box: $e", "TOOLS");
    }
  }

  String salt = '7f8a2c1e9d3b4f5a6b8b9c0d1e2f3a4b5c6d7e8f9a7c8d9e0f1a2b3c4d5e6f7a';
  if (useEnvSalt && env['APP_SALT'] != null) {
    final maybeSalt = env['APP_SALT'] ?? "";
    if (maybeSalt.isNotEmpty) {
      salt = maybeSalt;
    }
  }

  logln("Preparing for encryption using salt: $salt", "TOOLS");

  final key = await derivePasswordKey(password, salt);
  final cipher = HiveAesCipher(key);

  logln("Seeding settings...", "TOOLS");
  Hive.registerAdapter<SettingsModel>(SettingsAdapter());
  final settingsBox = await Hive.openBox<SettingsModel>('settings_box', encryptionCipher: cipher, crashRecovery: false);
  final encryptedMarker = await encryptValue("initialized", key);
  await settingsBox.put(
    SettingKey.vaultInitialized.id,
    SettingsModel(keyId: SettingKey.vaultInitialized.id, type: SettingKey.vaultInitialized.type, value: encryptedMarker),
  );

  logln("Marking dbversion to ${env['DB_VERSION'] ?? latestDB}", "TOOLS");

  await settingsBox.put(
    SettingKey.migrateVersion.id,
    SettingsModel(keyId: SettingKey.migrateVersion.id, type: SettingKey.migrateVersion.type, value: env['DB_VERSION'] ?? latestDB),
  );

  final cryptosBox = await Hive.openBox<CryptosModel>('cryptos_box');

  final txRepo = await Hive.openBox<TransactionsModel>('transactions_box', encryptionCipher: cipher, crashRecovery: false);

  final pxRepo = await Hive.openBox<PanelsModel>('panels_box', encryptionCipher: cipher, crashRecovery: false);

  final axRepo = await Hive.openBox<ArchivesModel>('archives_box', encryptionCipher: cipher, crashRecovery: false);

  final wxRepo = await Hive.openBox<WatchersModel>('watchers_box', encryptionCipher: null, crashRecovery: false);

  final rtRepo = await Hive.openBox<RatesModel>('rates_box', encryptionCipher: null, crashRecovery: false);

  if (seedCryptos) {
    logln("Seeding cryptos...", "TOOLS");
    await fetchCryptos(endpoint: requireEnv('CMC_ENDPOINT'), cryptosBox: cryptosBox);
  }

  if (seedTx) {
    logln("Seeding $transactionCount transactions with depth $transactionDepth...", "TOOLS");
    await generateTransactions(txRepo, transactionCount, transactionDepth);
  }

  if (seedWatchers) {
    logln("Seeding watchers...", "TOOLS");

    final txs = txRepo.values.toList();
    for (final tx in txs) {
      await wxRepo.add(
        WatchersModel(
          wid: generateId(),
          srId: tx.srId,
          rrId: tx.rrId,
          rates: Math.multiply(Math.divide(tx.rrAmount, tx.srAmount), Decimal.fromInt(2)),
          sent: 0,
          operator: 2,
          limit: 10,
          duration: 60,
          message: "",
          timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
          meta: {},
        ),
      );
    }
  }

  if (seedPanels) {
    logln("Seeding panels...", "TOOLS");
    final txs = txRepo.values.toList();
    final count = panelCount ?? txs.length;
    const batchSize = 1000;
    var batch = <String, PanelsModel>{};

    for (var i = 0; i < count; i++) {
      final tx = txs.isEmpty ? null : txs[i % txs.length];
      final srId = tx?.srId ?? pickCmcId(i);
      var rrId = tx?.rrId ?? pickCmcId(i + 1);
      if (srId == rrId) {
        rrId = pickCmcId(staticCmcIds.indexOf(srId) + 1);
      }

      final panel = PanelsModel(
        tid: 'edge-panel-${i.toString().padLeft(8, '0')}',
        srId: srId,
        srAmount: tx?.srAmount ?? Decimal.fromInt(1),
        rrId: rrId,
        digit: 6,
        rate: tx != null ? Math.divide(tx.rrAmount, tx.srAmount) : Decimal.one,
        order: i,
        meta: {},
      );
      batch[panel.tid] = panel;

      if (batch.length >= batchSize) {
        await pxRepo.putAll(batch);
        batch = <String, PanelsModel>{};
      }
    }

    if (batch.isNotEmpty) {
      await pxRepo.putAll(batch);
    }
    logln("Generated $count panels", "TOOLS");
  }

  if (seedRates) {
    logln("Seeding rates from transactions", "TOOLS");
    final txs = txRepo.values.toList();
    for (final tx in txs) {
      await rtRepo.add(
        RatesModel(
          sourceSymbol: pickCmcSymbol(tx.srId),
          sourceId: tx.srId,
          sourceAmount: Decimal.parse("1"),
          targetSymbol: pickCmcSymbol(tx.rrId),
          targetId: tx.rrId,
          targetAmount: Decimal.parse("0"),
          timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
        ),
      );
    }

    logln("Seeding rates from panels", "TOOLS");
    final pxs = pxRepo.values.toList();
    for (final tx in pxs) {
      await rtRepo.add(
        RatesModel(
          sourceSymbol: pickCmcSymbol(tx.srId),
          sourceId: tx.srId,
          sourceAmount: Decimal.parse("1"),
          targetSymbol: pickCmcSymbol(tx.rrId),
          targetId: tx.rrId,
          targetAmount: Decimal.parse("0"),
          timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
        ),
      );
    }

    logln("Seeding rates from watchers", "TOOLS");
    final wxs = wxRepo.values.toList();
    for (final tx in wxs) {
      await rtRepo.add(
        RatesModel(
          sourceSymbol: pickCmcSymbol(tx.srId),
          sourceId: tx.srId,
          sourceAmount: Decimal.parse("1"),
          targetSymbol: pickCmcSymbol(tx.rrId),
          targetId: tx.rrId,
          targetAmount: Decimal.parse("0"),
          timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
        ),
      );
    }
  }

  if (seedArchives) {
    logln("Seeding archives", "TOOLS");

    if (seedTx) {
      final data = await export<TransactionsModel>(txRepo);
      axRepo.add(
        ArchivesModel(
          aid: generateId(),
          type: ArchivesDataType.transactions.index,
          data: data,
          timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
          meta: {'notes': "Transactions data archived from cli"},
        ),
      );
    }

    if (seedPanels) {
      final data = await export<PanelsModel>(pxRepo);
      axRepo.add(
        ArchivesModel(
          aid: generateId(),
          type: ArchivesDataType.watchboards.index,
          data: data,
          timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
          meta: {'notes': "Watchboard data archived from cli"},
        ),
      );
    }

    if (seedWatchers) {
      final data = await export<WatchersModel>(wxRepo);
      axRepo.add(
        ArchivesModel(
          aid: generateId(),
          type: ArchivesDataType.watchers.index,
          data: data,
          timestamp: DateTime.now().toUtc().microsecondsSinceEpoch,
          meta: {'notes': "Watchers data archived from cli"},
        ),
      );
    }
  }

  logln("Vault seeded successfully.", "TOOLS");
  await Hive.close();
  exit(0);
}
