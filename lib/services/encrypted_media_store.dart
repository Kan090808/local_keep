import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:local_keep/models/media_attachment.dart';
import 'package:local_keep/services/crypto_service.dart';

class EncryptedMediaStore {
  static const String folderName = 'encrypted_media';

  Future<Directory> directory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/$folderName');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  Future<Uint8List?> read(String fileId) async {
    final file = File('${(await directory()).path}/$fileId.enc');
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> write(String fileId, Uint8List data) async {
    await File(
      '${(await directory()).path}/$fileId.enc',
    ).writeAsBytes(data, flush: true);
  }

  Future<void> clear() async {
    final mediaDir = await directory();
    await for (final entity in mediaDir.list(
      recursive: false,
      followLinks: false,
    )) {
      if (entity is File) await entity.delete();
    }
  }

  Future<Map<String, Uint8List>> snapshot() async {
    final result = <String, Uint8List>{};
    final mediaDir = await directory();
    await for (final entity in mediaDir.list(
      recursive: false,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.enc')) {
        result[path.basenameWithoutExtension(entity.path)] =
            await entity.readAsBytes();
      }
    }
    return result;
  }

  Future<void> replaceAll(Map<String, Uint8List> files) async {
    final current = await snapshot();
    try {
      await _writeAll(files);
      await _deleteExcept(files.keys.toSet());
    } catch (_) {
      await _writeAll(current);
      await _deleteExcept(current.keys.toSet());
      rethrow;
    }
  }

  Future<void> _writeAll(Map<String, Uint8List> files) async {
    for (final entry in files.entries) {
      await write(entry.key, entry.value);
    }
  }

  Future<void> _deleteExcept(Set<String> retainedIds) async {
    final mediaDir = await directory();
    await for (final entity in mediaDir.list(
      recursive: false,
      followLinks: false,
    )) {
      if (entity is File &&
          entity.path.endsWith('.enc') &&
          !retainedIds.contains(path.basenameWithoutExtension(entity.path))) {
        await entity.delete();
      }
    }
  }

  Future<void> delete(MediaAttachment media) async {
    final mediaDir = await directory();
    final mediaFile = File('${mediaDir.path}/${media.encryptedData}.enc');
    if (await mediaFile.exists()) await mediaFile.delete();
    if (media.thumbnailData != null) {
      final thumbnailFile = File('${mediaDir.path}/${media.thumbnailData}.enc');
      if (await thumbnailFile.exists()) await thumbnailFile.delete();
    }
  }

  Future<Uint8List> readDecrypted(String fileId, String password) async {
    final encrypted = await read(fileId);
    if (encrypted == null) throw Exception('Media file not found: $fileId');
    return CryptoService.decryptBytes(base64Encode(encrypted), password);
  }

  Future<Uint8List?> readDecryptedThumbnail(
    String? thumbnailId,
    String password,
  ) async {
    if (thumbnailId == null) return null;
    final encrypted = await read(thumbnailId);
    if (encrypted == null) return null;
    return CryptoService.decryptBytes(base64Encode(encrypted), password);
  }
}
