import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoService {
  static const _secureStorage = FlutterSecureStorage();
  static const _saltKey = 'encryption_salt';
  static const _passwordHashKey = 'password_hash';
  static const _iterations = 10000;
  static const _keyLength = 32;

  // Generate random bytes
  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  // Generate key from password using PBKDF2
  static Uint8List _deriveKeyFromPassword(String password, Uint8List salt) {
    List<int> passwordBytes = utf8.encode(password);
    var hmac = Hmac(sha256, passwordBytes);
    var key = List<int>.filled(_keyLength, 0);
    var result = List<int>.from(salt);

    for (var i = 0; i < _iterations; i++) {
      var hmacInput = List<int>.from(result);
      var mac = hmac.convert(hmacInput);
      result = mac.bytes;

      for (var j = 0; j < _keyLength; j++) {
        key[j] ^= result[j % result.length];
      }
    }

    return Uint8List.fromList(key);
  }

  // Get or create salt
  static Future<Uint8List> _getOrCreateSalt() async {
    final storedSalt = await _secureStorage.read(key: _saltKey);
    if (storedSalt != null) {
      return base64.decode(storedSalt);
    } else {
      final salt = _generateRandomBytes(32);
      await _secureStorage.write(key: _saltKey, value: base64.encode(salt));
      return salt;
    }
  }

  // Setup password
  static Future<void> setupPassword(String password) async {
    final salt = await _getOrCreateSalt();
    final key = _deriveKeyFromPassword(password, salt);
    await _secureStorage.write(
      key: _passwordHashKey,
      value: base64.encode(key),
    );
  }

  // Verify password
  static Future<bool> verifyPassword(String password) async {
    final storedHash = await _secureStorage.read(key: _passwordHashKey);
    if (storedHash == null) return false;

    final salt = await _getOrCreateSalt();
    final calculatedKey = _deriveKeyFromPassword(password, salt);

    return base64.encode(calculatedKey) == storedHash;
  }

  // Check if password is setup
  static Future<bool> isPasswordSetup() async {
    return await _secureStorage.read(key: _passwordHashKey) != null;
  }

  // Export crypto metadata (salt) for backup (password hash is not exported)
  static Future<Map<String, String>> exportCryptoMetadata() async {
    final salt = await _secureStorage.read(key: _saltKey);
    return {'salt': salt ?? ''};
  }

  // Import crypto metadata (salt). Caller must ensure this is safe to do.
  static Future<void> importCryptoMetadata({required String saltBase64}) async {
    await _secureStorage.write(key: _saltKey, value: saltBase64);
  }

  // Clear all sensitive keys (password hash and salt)
  static Future<void> clearAll() async {
    await _secureStorage.delete(key: _passwordHashKey);
    await _secureStorage.delete(key: _saltKey);
  }

  // Encrypt data
  static Future<String> encrypt(String data, String password) async {
    if (data.isEmpty) return '';

    final salt = await _getOrCreateSalt();
    final iv = _generateRandomBytes(16);
    final key = _deriveKeyFromPassword(password, salt);

    final encrypter = Encrypter(AES(Key(key)));
    final encrypted = encrypter.encrypt(data, iv: IV(iv));

    final combined = iv + encrypted.bytes;
    return base64.encode(combined);
  }

  // Decrypt data
  static Future<String> decrypt(String encryptedData, String password) async {
    if (encryptedData.isEmpty) return '';

    final salt = await _getOrCreateSalt();
    final key = _deriveKeyFromPassword(password, salt);

    final combined = base64.decode(encryptedData);
    final iv = combined.sublist(0, 16);
    final encryptedBytes = combined.sublist(16);

    final encrypter = Encrypter(AES(Key(key)));
    final encrypted = Encrypted(encryptedBytes);
    return encrypter.decrypt(encrypted, iv: IV(iv));
  }

  // Decrypt using an explicit salt (base64) — for portable backups
  static Future<String> decryptWithSalt(
    String encryptedData,
    String password,
    String saltBase64,
  ) async {
    if (encryptedData.isEmpty) return '';

    final salt = base64.decode(saltBase64);
    final key = _deriveKeyFromPassword(password, salt);

    final combined = base64.decode(encryptedData);
    final iv = combined.sublist(0, 16);
    final encryptedBytes = combined.sublist(16);

    final encrypter = Encrypter(AES(Key(key)));
    final encrypted = Encrypted(encryptedBytes);
    return encrypter.decrypt(encrypted, iv: IV(iv));
  }
}
