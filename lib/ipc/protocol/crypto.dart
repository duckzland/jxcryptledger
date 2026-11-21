import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';

class IpcCrypto {
  static Future<Sodium>? _sodiumFuture;
  static Sodium? _sodium;

  Uint8List? _rawKeyBytes;
  SecureKey? _secretKey;
  bool _keyDirty = false;

  static Future<Sodium> _getSodium() {
    final s = _sodium;
    if (s != null) return Future.value(s);
    return _sodiumFuture ??= Future.sync(() => SodiumInit.init()).then((instance) {
      _sodium = instance;
      return instance;
    });
  }

  IpcCrypto({dynamic key}) {
    if (key != null) {
      setSessionKey(key);
    }
  }

  static Uint8List createSessionKey(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = chars.codeUnitAt(rand.nextInt(chars.length));
    }
    return bytes;
  }

  void setSessionKey(dynamic key) {
    if (key is Uint8List) {
      _rawKeyBytes = key;
    } else if (key is String) {
      _rawKeyBytes = utf8.encode(key);
    } else {
      throw ArgumentError("Session key must be a String or a Uint8List.");
    }
    _keyDirty = true;
  }

  void clearSessionKey() {
    _rawKeyBytes = null;
    _secretKey?.dispose();
    _secretKey = null;
    _keyDirty = false;
  }

  bool get hasActiveKey => _rawKeyBytes != null;

  SecureKey _resolveKey(Sodium sodium) {
    final rawBytes = _rawKeyBytes;
    if (rawBytes == null) {
      throw StateError("[Crypto] Cannot process data payload without an active session key context.");
    }
    if (!_keyDirty && _secretKey != null) {
      return _secretKey!;
    }

    final keyLen = sodium.crypto.secretBox.keyBytes; // 32 bytes
    final normalized = rawBytes.length == keyLen ? rawBytes : sodium.crypto.genericHash(message: rawBytes, outLen: keyLen);

    _secretKey?.dispose();
    final key = SecureKey.fromList(sodium, normalized);
    _secretKey = key;
    _keyDirty = false;
    return key;
  }

  Future<Uint8List> encrypt(Uint8List plainBytes) async {
    if (_rawKeyBytes == null) {
      throw StateError("[Crypto] Cannot encrypt data payload without an active session key context.");
    }

    final sodium = _sodium ?? await _getSodium();
    final secretKey = _resolveKey(sodium);
    final nonceLen = sodium.crypto.secretBox.nonceBytes;
    final nonce = sodium.randombytes.buf(nonceLen);

    final cipherText = sodium.crypto.secretBox.easy(message: plainBytes, nonce: nonce, key: secretKey);

    final out = Uint8List(nonceLen + cipherText.length);
    out.setAll(0, nonce);
    out.setAll(nonceLen, cipherText);
    return out;
  }

  Future<Uint8List> decrypt(Uint8List encryptedBytes) async {
    if (_rawKeyBytes == null) {
      throw StateError("[Crypto] Cannot decrypt data payload without an active session key context.");
    }

    final sodium = _sodium ?? await _getSodium();
    final secretKey = _resolveKey(sodium);
    final nonceLen = sodium.crypto.secretBox.nonceBytes;
    if (encryptedBytes.length < nonceLen + sodium.crypto.secretBox.macBytes) {
      throw ArgumentError("[Crypto] Decryption validation failed. Payload too short.");
    }

    try {
      final nonce = Uint8List.sublistView(encryptedBytes, 0, nonceLen);
      final cipherText = Uint8List.sublistView(encryptedBytes, nonceLen);

      return sodium.crypto.secretBox.openEasy(cipherText: cipherText, nonce: nonce, key: secretKey);
    } catch (e) {
      throw ArgumentError("[Crypto] Decryption validation failed. Data payload has been tampered with or corrupted: $e");
    }
  }
}
