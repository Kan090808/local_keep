import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/app_logger.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/services/hive_database_service.dart';
import 'package:local_keep/services/media_service.dart';
import 'package:path_provider/path_provider.dart';

class BackupService {
  /// Current export format (authenticated envelope + metadata).
  static const int backupVersionV2 = 2;

  static const String _backupExtension = 'lkeep';

  static List<String> get backupExtensions => <String>[_backupExtension];

  static bool isSupportedBackupFile(String fileName) {
    final lowerName = fileName.toLowerCase();
    return lowerName.endsWith('.$_backupExtension');
  }

  /// Export notes + media as a password-protected v2 backup.
  static Future<String?> exportEncryptedBackup(String password) async {
    await HiveDatabaseService.initialize();
    await HiveDatabaseService.ensureOpen(password);

    final rawNotes = await HiveDatabaseService.getNotesRaw();
    final saltMetadata = await CryptoService.exportCryptoMetadata();
    final salt = saltMetadata['salt'] ?? '';

    if (salt.isEmpty) {
      throw Exception(
        'Encryption salt not found. Please set up the password first.',
      );
    }

    final notesPayload = rawNotes.map((note) => note.toMap()).toList();
    final mediaIds = <String>{};

    for (final note in rawNotes) {
      for (final media in note.mediaAttachments) {
        mediaIds.add(media.encryptedData);
        if (media.thumbnailData != null) {
          mediaIds.add(media.thumbnailData!);
        }
      }
    }

    final mediaPayload = <String, String>{};
    for (final mediaId in mediaIds) {
      final encryptedBytes = await MediaService.readEncryptedMediaFile(mediaId);
      if (encryptedBytes != null) {
        mediaPayload[mediaId] = base64Encode(encryptedBytes);
      }
    }

    final backupContent = <String, dynamic>{
      'version': backupVersionV2,
      'created_at': DateTime.now().toIso8601String(),
      'note_count': notesPayload.length,
      'media_count': mediaPayload.length,
      'notes': notesPayload,
      'media': mediaPayload,
    };

    // Fail if any note content cannot be authenticated/decrypted later by using
    // v2 encrypt for the outer envelope (always authenticated).
    final encryptedContent = await CryptoService.encrypt(
      jsonEncode(backupContent),
      password,
    );

    final wrapper = <String, dynamic>{
      'version': backupVersionV2,
      'salt': salt,
      'kdf_iterations':
          saltMetadata['kdf_iterations'] ??
          CryptoService.v2Iterations.toString(),
      'payload': encryptedContent,
    };

    final backupBytes = Uint8List.fromList(utf8.encode(jsonEncode(wrapper)));
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final suggestedFileName = 'local_keep_backup_$timestamp.$_backupExtension';

    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Local Keep Backup',
        fileName: suggestedFileName,
        allowedExtensions: [_backupExtension],
        type: FileType.custom,
        bytes: backupBytes,
      );

      if (savedPath == null) {
        return null;
      }

      return savedPath;
    } on UnsupportedError {
      final directory = await _fallbackDirectory();
      final filePath = '${directory.path}/$suggestedFileName';
      final file = File(filePath);
      await file.writeAsBytes(backupBytes, flush: true);
      return filePath;
    }
  }

  /// First-time restore (no existing password).
  static Future<int> importEncryptedBackupFirstTime({
    required Uint8List fileBytes,
    required String restorePassword,
  }) async {
    await HiveDatabaseService.initialize();

    final parsed = _parseBackupWrapper(fileBytes);
    final salt = parsed.salt;
    final payload = parsed.payload;
    final iterations = parsed.kdfIterations;

    final decryptedJson = CryptoService.decryptWithSaltV2(
      payload,
      restorePassword,
      salt,
      iterations: iterations,
    );

    final payloadMap = _decodePayloadMap(decryptedJson);
    final restoredNotes = _parseNotes(payloadMap['notes']);
    final mediaData = _requireMediaMap(payloadMap['media']);

    // Validate every note/media can be decrypted before mutating storage.
    await _validateBackupContents(
      notes: restoredNotes,
      mediaData: mediaData,
      password: restorePassword,
      salt: salt,
      iterations: iterations,
    );

    final restoredMedia = <String, Uint8List>{};
    for (final entry in mediaData.entries) {
      final value = entry.value;
      if (value is! String) {
        throw FormatException('Invalid media entry for ${entry.key}.');
      }
      restoredMedia[entry.key] = base64.decode(value);
    }

    // Import salt first so hive open / encrypt paths have consistent material.
    await CryptoService.importCryptoMetadata(
      saltBase64: salt,
      kdfIterations: iterations,
    );

    await CryptoService.setupPassword(restorePassword);
    await HiveDatabaseService.ensureOpen(restorePassword);

    await HiveDatabaseService.replaceAllNotesRaw(restoredNotes);
    await MediaService.replaceAllEncryptedMedia(restoredMedia);

    return restoredNotes.length;
  }

  /// Restore into an existing install.
  /// Decrypt failures abort — never treat ciphertext as plaintext.
  static Future<int> importEncryptedBackup({
    required Uint8List fileBytes,
    required String restorePassword,
    required String currentPassword,
  }) async {
    await HiveDatabaseService.initialize();

    final parsed = _parseBackupWrapper(fileBytes);
    final salt = parsed.salt;
    final payload = parsed.payload;
    final iterations = parsed.kdfIterations;

    final decryptedJson = CryptoService.decryptWithSaltV2(
      payload,
      restorePassword,
      salt,
      iterations: iterations,
    );

    final payloadMap = _decodePayloadMap(decryptedJson);
    final restoredNotes = _parseNotes(payloadMap['notes']);
    final mediaData = _requireMediaMap(payloadMap['media']);

    await _validateBackupContents(
      notes: restoredNotes,
      mediaData: mediaData,
      password: restorePassword,
      salt: salt,
      iterations: iterations,
    );

    final currentMeta = await CryptoService.exportCryptoMetadata();
    final currentSalt = currentMeta['salt'] ?? '';
    if (currentSalt.isEmpty) {
      throw Exception('Current encryption salt not found.');
    }
    final currentIterations = await CryptoService.getKdfIterations();

    final reEncryptedNotes = <Note>[];
    for (final note in restoredNotes) {
      final plain =
          note.content.isEmpty
              ? ''
              : CryptoService.decryptWithSaltV2(
                note.content,
                restorePassword,
                salt,
                iterations: iterations,
              );

      final reEncryptedContent =
          plain.isEmpty
              ? ''
              : await CryptoService.encrypt(plain, currentPassword);

      reEncryptedNotes.add(
        Note(
          id: note.id,
          content: reEncryptedContent,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          orderIndex: note.orderIndex,
          mediaAttachments: note.mediaAttachments,
        ),
      );
    }

    final reEncryptedMedia = <String, Uint8List>{};
    for (final entry in mediaData.entries) {
      final value = entry.value;
      if (value is! String) {
        throw FormatException('Invalid media entry for ${entry.key}.');
      }
      final decryptedMedia = CryptoService.decryptBytesWithSalt(
        base64.decode(value),
        restorePassword,
        salt,
        iterations: iterations,
      );
      reEncryptedMedia[entry.key] = CryptoService.encryptBytesWithSalt(
        decryptedMedia,
        currentPassword,
        currentSalt,
        iterations: currentIterations,
      );
    }

    await HiveDatabaseService.ensureOpen(currentPassword);

    final oldNotes = await HiveDatabaseService.getNotesRaw();
    final oldMedia = await MediaService.snapshotEncryptedMedia();
    try {
      await HiveDatabaseService.replaceAllNotesRaw(reEncryptedNotes);
      await MediaService.replaceAllEncryptedMedia(reEncryptedMedia);
    } catch (error) {
      AppLogger.e('Backup restore failed; rolling back', error);
      await HiveDatabaseService.replaceAllNotesRaw(oldNotes);
      await MediaService.replaceAllEncryptedMedia(oldMedia);
      rethrow;
    }

    return restoredNotes.length;
  }

  // ---------------------------------------------------------------------------
  // Parsing / validation helpers
  // ---------------------------------------------------------------------------

  static _BackupWrapper _parseBackupWrapper(Uint8List fileBytes) {
    final decoded = jsonDecode(utf8.decode(fileBytes));
    if (decoded is! Map) {
      throw const FormatException('Invalid backup format.');
    }
    final map = Map<String, dynamic>.from(decoded);

    final backupVersion = map['version'] as int?;
    if (backupVersion != backupVersionV2) {
      throw FormatException('Unsupported backup version: $backupVersion');
    }

    final salt = map['salt'] as String?;
    final payload = map['payload'] as String?;
    if (salt == null || salt.isEmpty || payload == null || payload.isEmpty) {
      throw const FormatException('Incomplete backup payload.');
    }

    final iterationsRaw = map['kdf_iterations']?.toString();
    final iterations =
        int.tryParse(iterationsRaw ?? '') ?? CryptoService.v2Iterations;

    return _BackupWrapper(
      salt: salt,
      payload: payload,
      kdfIterations: iterations,
    );
  }

  static Map<String, dynamic> _decodePayloadMap(String decryptedJson) {
    final payloadMap = jsonDecode(decryptedJson);
    if (payloadMap is! Map) {
      throw const FormatException('Invalid backup payload content.');
    }
    return Map<String, dynamic>.from(payloadMap);
  }

  static List<Note> _parseNotes(Object? notesData) {
    if (notesData is! List) {
      throw const FormatException('Missing notes in backup payload.');
    }
    final restoredNotes = <Note>[];
    for (final item in notesData) {
      if (item is Map<String, dynamic>) {
        restoredNotes.add(Note.fromMap(item));
      } else if (item is Map) {
        restoredNotes.add(Note.fromMap(Map<String, dynamic>.from(item)));
      } else {
        throw const FormatException('Invalid note entry in backup.');
      }
    }
    return restoredNotes;
  }

  static Map<String, dynamic> _requireMediaMap(Object? mediaData) {
    if (mediaData is! Map) {
      throw const FormatException('Missing media in backup payload.');
    }
    return Map<String, dynamic>.from(mediaData);
  }

  /// Decrypt every note and media object; throw on any failure (fail-closed).
  static Future<void> _validateBackupContents({
    required List<Note> notes,
    required Map<String, dynamic> mediaData,
    required String password,
    required String salt,
    required int iterations,
  }) async {
    for (final note in notes) {
      if (note.content.isEmpty) continue;
      try {
        CryptoService.decryptWithSaltV2(
          note.content,
          password,
          salt,
          iterations: iterations,
        );
      } catch (e) {
        throw FormatException(
          'Backup note ${note.id ?? "(unknown)"} failed authentication/decryption.',
        );
      }
    }

    for (final entry in mediaData.entries) {
      final value = entry.value;
      if (value is! String) {
        throw FormatException('Invalid media entry for ${entry.key}.');
      }
      try {
        CryptoService.decryptBytesWithSalt(
          base64.decode(value),
          password,
          salt,
          iterations: iterations,
        );
      } catch (e) {
        throw FormatException(
          'Backup media ${entry.key} failed authentication/decryption.',
        );
      }
    }
  }

  static Future<Directory> _fallbackDirectory() async {
    return getApplicationDocumentsDirectory();
  }
}

class _BackupWrapper {
  final String salt;
  final String payload;
  final int kdfIterations;

  _BackupWrapper({
    required this.salt,
    required this.payload,
    required this.kdfIterations,
  });
}
