import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dotenv/dotenv.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxledger/system/settings/keys.dart';

final env = DotEnv()..load();
final AesGcm aes = AesGcm.with256bits();

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

Future<void> main() async {
  final dir = requireEnv('APP_DATA_DIR');
  final password = requireEnv('APP_DB_PASSWORD');

  print("Initializing Hives...");
  Hive.init(dir);

  print("Wiping old boxes...");
  final boxes = ['settings_box'];

  for (final box in boxes) {
    try {
      await Hive.deleteBoxFromDisk(box);
      print("Deleted: $box");
    } catch (e) {
      print("Failed to delete $box: $e");
    }
  }

  String salt = '7f8a2c1e9d3b4f5a6b8b9c0d1e2f3a4b5c6d7e8f9a7c8d9e0f1a2b3c4d5e6f7a';

  print("Preparing for encryption using salt: $salt");

  final key = await derivePasswordKey(password, salt);
  final cipher = HiveAesCipher(key);

  print("Seeding settings...");
  final settingsBox = await Hive.openBox<dynamic>('settings_box', encryptionCipher: cipher, crashRecovery: false);
  final encryptedMarker = await encryptValue("initialized", key);
  await settingsBox.put(SettingKey.vaultInitialized.id, encryptedMarker);

  print("Vault seeded successfully.");
  await Hive.close();
  exit(0);
}
