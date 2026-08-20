import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/services/transactional_replacement.dart';

void main() {
  test('failed replacement restores the original snapshot', () async {
    final store = <String>['old note'];

    await expectLater(
      TransactionalReplacement.replace<String>(
        current: store,
        incoming: ['new note'],
        apply: (values) async {
          store
            ..clear()
            ..addAll(values);
          if (values.first == 'new note') {
            throw StateError('simulated write failure');
          }
        },
      ),
      throwsStateError,
    );

    expect(store, ['old note']);
  });

  test('tampered backup outer payload fails authentication (v2)', () {
    const password = 'backup-pass';
    final salt = base64Encode(List<int>.generate(32, (i) => 255 - i));
    final payload = jsonEncode({
      'version': 2,
      'notes': [],
      'media': <String, String>{},
    });

    final sealed = CryptoService.encryptWithSaltV2(payload, password, salt);
    final bytes = base64.decode(sealed);
    bytes[25] ^= 0xAA;

    expect(
      () =>
          CryptoService.decryptWithSaltV2(base64.encode(bytes), password, salt),
      throwsA(isA<FormatException>()),
    );
  });

  test('v2 media decrypt rejects short garbage', () {
    const password = 'x';
    final salt = base64Encode(List<int>.filled(32, 1));
    expect(
      () => CryptoService.decryptBytesWithSalt(
        Uint8List.fromList([1, 2, 3]),
        password,
        salt,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
