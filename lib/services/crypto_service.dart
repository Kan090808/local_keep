import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The app's single encryption format.
///
/// Format: `LK2\x01 || IV(16) || ciphertext || HMAC-SHA256(32)`.
class CryptoService {
  static const _secureStorage = FlutterSecureStorage();

  static const _saltKey = 'encryption_salt';
  static const _passwordHashKey = 'password_hash';

  static const v2Iterations = 210000;
  static const v2KeyLength = 32;
  static final v2Magic = Uint8List.fromList([0x4C, 0x4B, 0x32, 0x01]);

  static const _labelContent = 'localkeep-v2-content';
  static const _labelMac = 'localkeep-v2-mac';
  static const _labelHive = 'localkeep-v2-hive';
  static const _labelVerify = 'localkeep-v2-verify';

  static Uint8List generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static bool constantTimeStringEquals(String a, String b) {
    return constantTimeEquals(utf8.encode(a), utf8.encode(b));
  }

  static Uint8List pbkdf2HmacSha256({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int dkLen,
  }) {
    final hmac = Hmac(sha256, password);
    const hLen = 32;
    final blockCount = (dkLen + hLen - 1) ~/ hLen;
    final derived = <int>[];

    for (var block = 1; block <= blockCount; block++) {
      final blockIndex = ByteData(4)..setUint32(0, block, Endian.big);
      var u = hmac.convert([...salt, ...blockIndex.buffer.asUint8List()]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      derived.addAll(t);
    }
    return Uint8List.fromList(derived.sublist(0, dkLen));
  }

  static Uint8List deriveMasterKeyV2(String password, Uint8List salt) {
    return pbkdf2HmacSha256(
      password: utf8.encode(password),
      salt: salt,
      iterations: v2Iterations,
      dkLen: v2KeyLength,
    );
  }

  static Uint8List _deriveSubkey(Uint8List master, String label) {
    return Uint8List.fromList(
      Hmac(sha256, master).convert(utf8.encode(label)).bytes,
    );
  }

  static Uint8List contentKeyV2(Uint8List master) =>
      _deriveSubkey(master, _labelContent);
  static Uint8List macKeyV2(Uint8List master) =>
      _deriveSubkey(master, _labelMac);
  static Uint8List hiveKeyV2(Uint8List master) =>
      _deriveSubkey(master, _labelHive);
  static Uint8List verifierV2(Uint8List master) =>
      _deriveSubkey(master, _labelVerify);

  static bool isV2CipherBytes(Uint8List bytes) {
    if (bytes.length < v2Magic.length + 16 + 16 + 32) return false;
    for (var i = 0; i < v2Magic.length; i++) {
      if (bytes[i] != v2Magic[i]) return false;
    }
    return true;
  }

  static Future<Uint8List> getOrCreateSalt() async {
    final storedSalt = await _secureStorage.read(key: _saltKey);
    if (storedSalt != null && storedSalt.isNotEmpty) {
      return base64.decode(storedSalt);
    }
    final salt = generateRandomBytes(32);
    await _secureStorage.write(key: _saltKey, value: base64.encode(salt));
    return salt;
  }

  static Future<Uint8List?> readSalt() async {
    final storedSalt = await _secureStorage.read(key: _saltKey);
    if (storedSalt == null || storedSalt.isEmpty) return null;
    return base64.decode(storedSalt);
  }

  static Future<void> setupPassword(String password) async {
    final salt = await getOrCreateSalt();
    final master = deriveMasterKeyV2(password, salt);
    await _secureStorage.write(
      key: _passwordHashKey,
      value: base64.encode(verifierV2(master)),
    );
  }

  static Future<bool> verifyPassword(String password) async {
    final storedHash = await _secureStorage.read(key: _passwordHashKey);
    final salt = await readSalt();
    if (storedHash == null || salt == null) return false;

    final master = deriveMasterKeyV2(password, salt);
    return constantTimeStringEquals(
      base64.encode(verifierV2(master)),
      storedHash,
    );
  }

  static Future<bool> isPasswordSetup() async {
    return await _secureStorage.read(key: _passwordHashKey) != null;
  }

  static Future<Map<String, String>> exportCryptoMetadata() async {
    return {'salt': (await _secureStorage.read(key: _saltKey)) ?? ''};
  }

  static Future<void> importCryptoMetadata({required String saltBase64}) async {
    await _secureStorage.write(key: _saltKey, value: saltBase64);
  }

  static Future<void> clearAll() async {
    await _secureStorage.delete(key: _passwordHashKey);
    await _secureStorage.delete(key: _saltKey);
  }

  static Future<String> encrypt(String data, String password) async {
    if (data.isEmpty) return '';
    final salt = await getOrCreateSalt();
    return encryptWithSaltV2(data, password, base64.encode(salt));
  }

  static Future<String> decrypt(String encryptedData, String password) async {
    if (encryptedData.isEmpty) return '';
    final salt = await readSalt();
    if (salt == null) throw StateError('Encryption salt missing.');
    return decryptWithSaltV2(encryptedData, password, base64.encode(salt));
  }

  static String encryptWithSaltV2(
    String data,
    String password,
    String saltBase64,
  ) {
    if (data.isEmpty) return '';
    final salt = base64.decode(saltBase64);
    final master = deriveMasterKeyV2(password, salt);
    return base64.encode(
      encryptBytesV2(
        Uint8List.fromList(utf8.encode(data)),
        contentKeyV2(master),
        macKeyV2(master),
      ),
    );
  }

  static String decryptWithSaltV2(
    String encryptedData,
    String password,
    String saltBase64,
  ) {
    if (encryptedData.isEmpty) return '';
    final salt = base64.decode(saltBase64);
    final master = deriveMasterKeyV2(password, salt);
    return utf8.decode(
      decryptBytesV2(
        base64.decode(encryptedData),
        contentKeyV2(master),
        macKeyV2(master),
      ),
    );
  }

  static Future<String> encryptBytes(Uint8List data, String password) async {
    if (data.isEmpty) return '';
    final salt = await getOrCreateSalt();
    return base64.encode(
      encryptBytesWithSalt(data, password, base64.encode(salt)),
    );
  }

  static Uint8List encryptBytesWithSalt(
    Uint8List data,
    String password,
    String saltBase64,
  ) {
    if (data.isEmpty) return Uint8List(0);
    final salt = base64.decode(saltBase64);
    final master = deriveMasterKeyV2(password, salt);
    return encryptBytesV2(data, contentKeyV2(master), macKeyV2(master));
  }

  static Future<Uint8List> decryptBytes(
    String encryptedData,
    String password,
  ) async {
    if (encryptedData.isEmpty) return Uint8List(0);
    final salt = await readSalt();
    if (salt == null) throw StateError('Encryption salt missing.');
    return decryptBytesWithSalt(
      base64.decode(encryptedData),
      password,
      base64.encode(salt),
    );
  }

  static Uint8List decryptBytesWithSalt(
    Uint8List encryptedBytes,
    String password,
    String saltBase64,
  ) {
    if (encryptedBytes.isEmpty) return Uint8List(0);
    final salt = base64.decode(saltBase64);
    final master = deriveMasterKeyV2(password, salt);
    return decryptBytesV2(
      encryptedBytes,
      contentKeyV2(master),
      macKeyV2(master),
    );
  }

  static Uint8List encryptBytesV2(
    Uint8List data,
    Uint8List contentKey,
    Uint8List macKey,
  ) {
    final iv = generateRandomBytes(16);
    final encrypted = Encrypter(
      AES(Key(contentKey)),
    ).encryptBytes(data, iv: IV(iv));
    final body = Uint8List.fromList([...v2Magic, ...iv, ...encrypted.bytes]);
    final mac = Hmac(sha256, macKey).convert(body).bytes;
    return Uint8List.fromList([...body, ...mac]);
  }

  static Uint8List decryptBytesV2(
    Uint8List sealed,
    Uint8List contentKey,
    Uint8List macKey,
  ) {
    if (!isV2CipherBytes(sealed)) {
      throw const FormatException('Invalid v2 ciphertext.');
    }
    final macStart = sealed.length - 32;
    final body = sealed.sublist(0, macStart);
    final mac = sealed.sublist(macStart);
    final expected = Hmac(sha256, macKey).convert(body).bytes;
    if (!constantTimeEquals(mac, expected)) {
      throw const FormatException('Ciphertext authentication failed.');
    }
    final iv = body.sublist(v2Magic.length, v2Magic.length + 16);
    final ciphertext = body.sublist(v2Magic.length + 16);
    return Uint8List.fromList(
      Encrypter(
        AES(Key(contentKey)),
      ).decryptBytes(Encrypted(ciphertext), iv: IV(iv)),
    );
  }
}
