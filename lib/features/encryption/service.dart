import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../app/constants.dart';

class EncryptionService {
  EncryptionService._();

  static final EncryptionService instance = EncryptionService._();

  final AesGcm _cipher = AesGcm.with256bits();
  SecretKey? _secretKey;

  Future<void> generateKey() async {
    _secretKey = await _cipher.newSecretKey();
  }

  Future<void> loadKey(List<int> keyBytes) async {
    _secretKey = SecretKey(keyBytes);
  }

  Future<List<int>> exportKey() async {
    if (_secretKey == null) {
      throw Exception('Encryption key not initialized');
    }
    return await _secretKey!.extractBytes();
  }

  Future<String> encrypt(String plainText) async {
    if (_secretKey == null) {
      throw Exception('Encryption key not initialized');
    }

    final nonce = _cipher.newNonce();
    final secretBox = await _cipher.encrypt(utf8.encode(plainText), secretKey: _secretKey!, nonce: nonce);

    final combined = <int>[...nonce, ...secretBox.cipherText, ...secretBox.mac.bytes];

    return base64Encode(combined);
  }

  Future<String> decrypt(String encryptedBase64) async {
    if (_secretKey == null) {
      throw Exception('Encryption key not initialized');
    }

    final data = base64Decode(encryptedBase64);

    const nonceLength = 12;
    const macLength = 16;

    final nonce = data.sublist(0, nonceLength);
    final mac = Mac(data.sublist(data.length - macLength));
    final cipherText = data.sublist(nonceLength, data.length - macLength);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);

    final decrypted = await _cipher.decrypt(secretBox, secretKey: _secretKey!);

    return utf8.decode(decrypted);
  }

  Future<Uint8List> loadPasswordKey(String password) async {
    final String saltValue = dotenv.get('APP_SALT', fallback: appSalt);

    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);

    final secretKey = await pbkdf2.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: utf8.encode(saltValue));

    _secretKey = secretKey;

    final bytes = await secretKey.extractBytes();
    return Uint8List.fromList(bytes);
  }
}
