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
  static const _iterations = 100000; // Increased from 10000 for better security
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
    // Use a combination of device-specific salt and password-derived key
    final deviceSalt = await _getDeviceSpecificSalt();
    final passwordSalt = await _getOrCreateSalt();
    
    // Create a stronger key by combining device salt with password
    final combinedSalt = Uint8List.fromList([...deviceSalt, ...passwordSalt]);
    final key = Key(_deriveKeyFromPassword(password, combinedSalt).sublist(0, 32));
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key));

    // Encrypt the password with itself as part of the key derivation
    final encrypted = encrypter.encrypt(password, iv: iv);

    // Store only IV and encrypted data (not the salts for better security)
    final combined = iv.bytes + encrypted.bytes;
    return base64.encode(combined);
  }

  // Decrypt the memory-encrypted password when needed
  // Note: This requires the original password to decrypt, providing circular security
  static Future<String> decryptMemoryEncryptedPassword(
    String encryptedPassword, 
    String originalPassword,
  ) async {
    try {
      final combined = base64.decode(encryptedPassword);

      // Extract IV and encrypted data
      final ivBytes = combined.sublist(0, 16);
      final encryptedBytes = combined.sublist(16);

      // Recreate the same key used for encryption
      final deviceSalt = await _getDeviceSpecificSalt();
      final passwordSalt = await _getOrCreateSalt();
      final combinedSalt = Uint8List.fromList([...deviceSalt, ...passwordSalt]);
      final key = Key(_deriveKeyFromPassword(originalPassword, combinedSalt).sublist(0, 32));
      
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
    final iv = _generateRandomBytes(16); // Generate a new IV for each encryption
    final key = _deriveKeyFromPassword(password, salt);

    final encrypter = Encrypter(AES(Key(key)));
    final encrypted = encrypter.encrypt(data, iv: IV(iv));

    // Create HMAC for integrity verification
    final hmac = await _createHMAC(iv + encrypted.bytes, password, salt);

    // Concatenate IV, encrypted data, and HMAC, then encode in Base64
    final combined = iv + encrypted.bytes + hmac;
    return base64.encode(combined);
  }

  // Decrypt data using the password
  static Future<String> decrypt(String encryptedData, String password) async {
    if (encryptedData.isEmpty) {
      return ''; // Return an empty string if data is empty
    }

    final salt = await _getOrCreateSalt();
    final key = _deriveKeyFromPassword(password, salt);

    // Decode the Base64 encoded data
    final combined = base64.decode(encryptedData);

    // Handle legacy format (without HMAC) for backward compatibility
    if (combined.length < 48) { // IV(16) + data + HMAC(32) minimum
      // Legacy format: IV + encrypted data only
      final iv = combined.sublist(0, 16);
      final encryptedBytes = combined.sublist(16);
      
      final encrypter = Encrypter(AES(Key(key)));
      final encrypted = Encrypted(encryptedBytes);
      return encrypter.decrypt(encrypted, iv: IV(iv));
    }

    // New format: IV + encrypted data + HMAC
    final iv = combined.sublist(0, 16);
    final encryptedBytes = combined.sublist(16, combined.length - 32);
    final receivedHmac = combined.sublist(combined.length - 32);

    // Verify HMAC for integrity
    final expectedHmac = await _createHMAC(iv + encryptedBytes, password, salt);
    if (!_constantTimeEquals(receivedHmac, expectedHmac)) {
      throw Exception('Data integrity verification failed');
    }

    final encrypter = Encrypter(AES(Key(key)));
    final encrypted = Encrypted(encryptedBytes);
    return encrypter.decrypt(encrypted, iv: IV(iv));
  }
  // Get device-specific salt for memory encryption
  static Future<Uint8List> _getDeviceSpecificSalt() async {
    const deviceSaltKey = 'device_specific_salt';
    final storedSalt = await _secureStorage.read(key: deviceSaltKey);
    if (storedSalt != null) {
      return base64.decode(storedSalt);
    } else {
      final salt = _generateRandomBytes(32);
      await _secureStorage.write(key: deviceSaltKey, value: base64.encode(salt));
      return salt;
    }
  }

  // Create HMAC for data integrity verification
  static Future<Uint8List> _createHMAC(
    Uint8List data,
    String password,
    Uint8List salt,
  ) async {
    final hmacKey = _deriveKeyFromPassword(password + '_hmac', salt);
    final hmac = Hmac(sha256, hmacKey);
    final digest = hmac.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  // Constant-time comparison to prevent timing attacks
  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  // Secure memory cleanup (best effort)
  static void _secureCleanup(String sensitiveData) {
    // In Dart, we can't directly overwrite memory, but we can help GC
    // by creating noise and triggering collection
    for (int i = 0; i < 10; i++) {
      final noise = List.generate(sensitiveData.length, (_) => Random().nextInt(256));
      noise.clear();
    }
  }
}
