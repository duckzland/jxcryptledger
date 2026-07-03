import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class CoreIpcCrypto {
  final _algorithm = AesGcm.with256bits();
  SecretKey? _secretKey;

  CoreIpcCrypto({dynamic key}) {
    if (key != null) {
      setSessionKey(key);
    }
  }

  static Uint8List createSessionKey(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return utf8.encode(List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join());
  }

  void setSessionKey(dynamic key) {
    Uint8List keyBytes;
    if (key is Uint8List) {
      keyBytes = key;
    } else if (key is String) {
      keyBytes = utf8.encode(key);
    } else {
      throw ArgumentError("Session key must be a String or a Uint8List.");
    }

    _secretKey = SecretKey(keyBytes);
  }

  void clearSessionKey() {
    _secretKey = null;
  }

  bool get hasActiveKey => _secretKey != null;

  Future<Uint8List> encrypt(Uint8List plainBytes) async {
    if (_secretKey == null) {
      throw StateError("[Crypto] Cannot encrypt data payload without an active session key context.");
    }

    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(plainBytes, secretKey: _secretKey!, nonce: nonce);

    return Uint8List.fromList(secretBox.concatenation());
  }

  Future<Uint8List> decrypt(Uint8List encryptedBytes) async {
    if (_secretKey == null) {
      throw StateError("[Crypto] Cannot decrypt data payload without an active session key context.");
    }

    try {
      final secretBox = SecretBox.fromConcatenation(
        encryptedBytes,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );

      final decryptedList = await _algorithm.decrypt(secretBox, secretKey: _secretKey!);

      return Uint8List.fromList(decryptedList);
    } catch (e) {
      throw ArgumentError("[Crypto] Decryption validation failed. Data payload has been tampered with or corrupted.");
    }
  }
}
