import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class EncryptionService {
  EncryptionService._();

  static final EncryptionService instance = EncryptionService._();

  // AES-GCM (256-bit)
  final AesGcm _cipher = AesGcm.with256bits();

  // In-memory key (you can later store it securely)
  SecretKey? _secretKey;

  /// Generates a new AES-256 key
  Future<void> generateKey() async {
    _secretKey = await _cipher.newSecretKey();
  }

  /// Loads an existing key from raw bytes
  Future<void> loadKey(List<int> keyBytes) async {
    _secretKey = SecretKey(keyBytes);
  }

  /// Returns the raw key bytes (for saving)
  Future<List<int>> exportKey() async {
    if (_secretKey == null) {
      throw Exception('Encryption key not initialized');
    }
    return await _secretKey!.extractBytes();
  }

  /// Encrypts a string and returns base64 output
  Future<String> encrypt(String plainText) async {
    if (_secretKey == null) {
      throw Exception('Encryption key not initialized');
    }

    final nonce = _cipher.newNonce();
    final secretBox = await _cipher.encrypt(
      utf8.encode(plainText),
      secretKey: _secretKey!,
      nonce: nonce,
    );

    // Combine nonce + ciphertext + MAC
    final combined = <int>[
      ...nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];

    return base64Encode(combined);
  }

  /// Decrypts a base64 string
  Future<String> decrypt(String encryptedBase64) async {
    if (_secretKey == null) {
      throw Exception('Encryption key not initialized');
    }

    final data = base64Decode(encryptedBase64);

    // AES-GCM uses:
    // - 12 bytes nonce
    // - last 16 bytes MAC
    const nonceLength = 12;
    const macLength = 16;

    final nonce = data.sublist(0, nonceLength);
    final mac = Mac(data.sublist(data.length - macLength));
    final cipherText = data.sublist(nonceLength, data.length - macLength);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);

    final decrypted = await _cipher.decrypt(secretBox, secretKey: _secretKey!);

    return utf8.decode(decrypted);
  }

  /// Derive AES-256 key from a password (PBKDF2)
  Future<void> loadPasswordKey(String password) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode("jxcryptledger-salt"),
    );

    _secretKey = secretKey;
  }
}
