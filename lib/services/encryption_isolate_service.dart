import 'dart:isolate';
import 'dart:async';
import 'package:local_keep/services/crypto_service.dart';

class EncryptionIsolateService {
  static Isolate? _encryptionIsolate;
  static SendPort? _sendPort;
  static final Map<String, Completer> _pendingRequests = {};
  static int _requestId = 0;

  // Initialize the encryption isolate
  static Future<void> initialize() async {
    if (_encryptionIsolate != null) return;

    final receivePort = ReceivePort();
    _encryptionIsolate = await Isolate.spawn(
      _isolateEntryPoint,
      receivePort.sendPort,
    );

    final completer = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        completer.complete(message);
      } else if (message is Map) {
        final requestId = message['requestId'] as String;
        final completer = _pendingRequests.remove(requestId);
        if (completer != null) {
          if (message['error'] != null) {
            completer.completeError(message['error']);
          } else {
            completer.complete(message['result']);
          }
        }
      }
    });

    await completer.future;
  }

  // Dispose of the isolate
  static void dispose() {
    _encryptionIsolate?.kill();
    _encryptionIsolate = null;
    _sendPort = null;
    _pendingRequests.clear();
  }

  // Encrypt data asynchronously
  static Future<String> encryptAsync(String data, String password) async {
    if (_sendPort == null) await initialize();

    final requestId = 'encrypt_${_requestId++}';
    final completer = Completer<String>();
    _pendingRequests[requestId] = completer;

    _sendPort!.send({
      'type': 'encrypt',
      'requestId': requestId,
      'data': data,
      'password': password,
    });

    return completer.future;
  }

  // Decrypt data asynchronously
  static Future<String> decryptAsync(
    String encryptedData,
    String password,
  ) async {
    if (_sendPort == null) await initialize();

    final requestId = 'decrypt_${_requestId++}';
    final completer = Completer<String>();
    _pendingRequests[requestId] = completer;

    _sendPort!.send({
      'type': 'decrypt',
      'requestId': requestId,
      'encryptedData': encryptedData,
      'password': password,
    });

    return completer.future;
  }

  // Batch encrypt multiple items
  static Future<List<String>> encryptBatch(
    List<String> dataList,
    String password,
  ) async {
    if (_sendPort == null) await initialize();

    final requestId = 'encryptBatch_${_requestId++}';
    final completer = Completer<List<String>>();
    _pendingRequests[requestId] = completer;

    _sendPort!.send({
      'type': 'encryptBatch',
      'requestId': requestId,
      'dataList': dataList,
      'password': password,
    });

    return completer.future;
  }

  // Batch decrypt multiple items
  static Future<List<String>> decryptBatch(
    List<String> encryptedDataList,
    String password,
  ) async {
    if (_sendPort == null) await initialize();

    final requestId = 'decryptBatch_${_requestId++}';
    final completer = Completer<List<String>>();
    _pendingRequests[requestId] = completer;

    _sendPort!.send({
      'type': 'decryptBatch',
      'requestId': requestId,
      'encryptedDataList': encryptedDataList,
      'password': password,
    });

    return completer.future;
  }

  // Isolate entry point
  static void _isolateEntryPoint(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is Map) {
        final type = message['type'] as String;
        final requestId = message['requestId'] as String;

        try {
          dynamic result;

          switch (type) {
            case 'encrypt':
              result = await CryptoService.encrypt(
                message['data'] as String,
                message['password'] as String,
              );
              break;
            case 'decrypt':
              result = await CryptoService.decrypt(
                message['encryptedData'] as String,
                message['password'] as String,
              );
              break;
            case 'encryptBatch':
              final dataList = message['dataList'] as List<String>;
              final password = message['password'] as String;
              result = <String>[];
              for (final data in dataList) {
                final encrypted = await CryptoService.encrypt(data, password);
                result.add(encrypted);
              }
              break;
            case 'decryptBatch':
              final encryptedDataList =
                  message['encryptedDataList'] as List<String>;
              final password = message['password'] as String;
              result = <String>[];
              for (final encryptedData in encryptedDataList) {
                final decrypted = await CryptoService.decrypt(
                  encryptedData,
                  password,
                );
                result.add(decrypted);
              }
              break;
          }

          mainSendPort.send({'requestId': requestId, 'result': result});
        } catch (e) {
          mainSendPort.send({'requestId': requestId, 'error': e.toString()});
        }
      }
    });
  }
}
