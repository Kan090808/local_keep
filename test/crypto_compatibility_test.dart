import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_keep/services/crypto_service.dart';

void main() {
  const password = 'current-password';
  final salt = base64Encode(List<int>.generate(32, (index) => index));

  test('v2 text round-trip authenticates the ciphertext', () {
    const text = 'secure note 🔐';
    final sealed = CryptoService.encryptWithSaltV2(text, password, salt);

    expect(CryptoService.decryptWithSaltV2(sealed, password, salt), text);

    final bytes = base64.decode(sealed);
    bytes[20] ^= 0xFF;
    expect(
      () =>
          CryptoService.decryptWithSaltV2(base64.encode(bytes), password, salt),
      throwsA(isA<FormatException>()),
    );
  });

  test('v2 media round-trip authenticates the ciphertext', () {
    final media = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final sealed = CryptoService.encryptBytesWithSalt(media, password, salt);

    expect(CryptoService.isV2CipherBytes(sealed), isTrue);
    expect(
      CryptoService.decryptBytesWithSalt(sealed, password, salt),
      orderedEquals(media),
    );

    sealed[sealed.length - 1] ^= 0x01;
    expect(
      () => CryptoService.decryptBytesWithSalt(sealed, password, salt),
      throwsA(isA<FormatException>()),
    );
  });

  test('v2 verifier is separate from the content key', () {
    final saltBytes = base64.decode(salt);
    final master = CryptoService.deriveMasterKeyV2(password, saltBytes);
    expect(
      CryptoService.verifierV2(master),
      isNot(equals(CryptoService.contentKeyV2(master))),
    );
  });

  test('invalid ciphertext is rejected', () {
    expect(
      () => CryptoService.decryptBytesWithSalt(
        Uint8List.fromList([1, 2, 3]),
        password,
        salt,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('PBKDF2 is stable for the same inputs', () {
    final first = CryptoService.pbkdf2HmacSha256(
      password: utf8.encode('password'),
      salt: utf8.encode('salt'),
      iterations: 2,
      dkLen: 32,
    );
    final second = CryptoService.pbkdf2HmacSha256(
      password: utf8.encode('password'),
      salt: utf8.encode('salt'),
      iterations: 2,
      dkLen: 32,
    );

    expect(first, orderedEquals(second));
    expect(first, hasLength(32));
  });
}
