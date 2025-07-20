import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CryptoService {
  static const _secureStorage = FlutterSecureStorage();
  static const _ivKey = 'encryption_iv';
  static const _saltKey = 'encryption_salt';
  static const _passwordHashKey = 'password_hash';
  static const _iterations = 10000;
  static const _keyLength = 32; // 256 bits

  // Generate random bytes for salt and IV
  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  // Generate a key from the password using PBKDF2
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

  // Store or retrieve the IV
  static Future<Uint8List> _getOrCreateIV() async {
    final storedIV = await _secureStorage.read(key: _ivKey);
    if (storedIV != null) {
      return base64.decode(storedIV);
    } else {
      final iv = _generateRandomBytes(16); // 128 bits for AES
      await _secureStorage.write(key: _ivKey, value: base64.encode(iv));
      return iv;
    }
  }

  // Store or retrieve the salt
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

  // Create and store password hash
  static Future<void> setupPassword(String password) async {
    final salt = await _getOrCreateSalt();
    final key = _deriveKeyFromPassword(password, salt);
    await _secureStorage.write(
      key: _passwordHashKey,
      value: base64.encode(key),
    );
    // Also initialize IV for encryption
    await _getOrCreateIV();
  }

  // Verify password against stored hash
  static Future<bool> verifyPassword(String password) async {
    final storedHash = await _secureStorage.read(key: _passwordHashKey);
    if (storedHash == null) return false;

    final salt = await _getOrCreateSalt();
    final calculatedKey = _deriveKeyFromPassword(password, salt);

    return base64.encode(calculatedKey) == storedHash;
  }

  // Check if password has been set up
  static Future<bool> isPasswordSetup() async {
    return await _secureStorage.read(key: _passwordHashKey) != null;
  }

  // Create an encrypted version of the password for in-memory storage
  static Future<String> createMemoryEncryptedPassword(String password) async {
    // Use a simple encryption with a fixed key for memory storage
    // This is just to obfuscate the password in memory, not for strong security
    final key = Key.fromSecureRandom(32);
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key));

    final encrypted = encrypter.encrypt(password, iv: iv);

    // Combine key, iv, and encrypted data for decryption later
    final combined = key.bytes + iv.bytes + encrypted.bytes;
    return base64.encode(combined);
  }

  // Decrypt the memory-encrypted password when needed
  static String decryptMemoryEncryptedPassword(String encryptedPassword) {
    try {
      final combined = base64.decode(encryptedPassword);

      // Extract key, iv, and encrypted data
      final keyBytes = combined.sublist(0, 32);
      final ivBytes = combined.sublist(32, 48);
      final encryptedBytes = combined.sublist(48);

      final key = Key(keyBytes);
      final iv = IV(ivBytes);
      final encrypter = Encrypter(AES(key));

      return encrypter.decrypt(Encrypted(encryptedBytes), iv: iv);
    } catch (e) {
      throw Exception('Failed to decrypt memory-encrypted password: $e');
    }
  }

  // Encrypt data using the password
  static Future<String> encrypt(String data, String password) async {
    if (data.isEmpty) {
      return ''; // Return an empty string if data is empty
    }

    final salt = await _getOrCreateSalt();
    final iv = _generateRandomBytes(
      16,
    ); // Generate a new IV for each encryption
    final key = _deriveKeyFromPassword(password, salt);

    final encrypter = Encrypter(AES(Key(key)));
    final encrypted = encrypter.encrypt(data, iv: IV(iv));

    // Concatenate IV with encrypted data and encode in Base64
    final ivAndEncrypted = iv + encrypted.bytes;
    return base64.encode(ivAndEncrypted);
  }

  // Decrypt data using the password
  static Future<String> decrypt(String encryptedData, String password) async {
    if (encryptedData.isEmpty) {
      return ''; // Return an empty string if data is empty
    }

    final salt = await _getOrCreateSalt();
    final key = _deriveKeyFromPassword(password, salt);

    // Decode the Base64 encoded data
    final ivAndEncrypted = base64.decode(encryptedData);

    // Extract the IV and the encrypted data
    final iv = ivAndEncrypted.sublist(0, 16);
    final encryptedBytes = ivAndEncrypted.sublist(16);

    final encrypter = Encrypter(AES(Key(key)));
    final encrypted = Encrypted(encryptedBytes);

    final decrypted = encrypter.decrypt(encrypted, iv: IV(iv));
    return decrypted;
  }
}
