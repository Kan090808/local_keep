import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/services/hive_database_service.dart';
import 'package:local_keep/services/media_service.dart';
import 'package:path_provider/path_provider.dart';

class BackupService {
  static const int _backupVersion = 1;
  static const String _backupExtension = 'lkeep';

  static List<String> get backupExtensions => <String>[_backupExtension];

  static bool isSupportedBackupFile(String fileName) {
    final lowerName = fileName.toLowerCase();
    return lowerName.endsWith('.$_backupExtension');
  }

  /// Export all notes and encrypted media into a password-protected backup file.
  ///
  /// Returns the saved file path when successful or `null` when the user cancels.
  static Future<String?> exportEncryptedBackup(String password) async {
    await HiveDatabaseService.initialize();

    final rawNotes = await HiveDatabaseService.getNotesRaw();
    final saltMetadata = await CryptoService.exportCryptoMetadata();
    final salt = saltMetadata['salt'] ?? '';

    if (salt.isEmpty) {
      throw Exception(
        'Encryption salt not found. Please set up the password first.',
      );
    }

    // Collect notes and media references
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

    // Read encrypted media bytes
    final mediaPayload = <String, String>{};
    for (final mediaId in mediaIds) {
      final encryptedBytes = await MediaService.readEncryptedMediaFile(mediaId);
      if (encryptedBytes != null) {
        mediaPayload[mediaId] = base64Encode(encryptedBytes);
      }
    }

    final backupContent = <String, dynamic>{
      'version': _backupVersion,
      'created_at': DateTime.now().toIso8601String(),
      'note_count': notesPayload.length,
      'media_count': mediaPayload.length,
      'notes': notesPayload,
      'media': mediaPayload,
    };

    final encryptedContent = await CryptoService.encrypt(
      jsonEncode(backupContent),
      password,
    );

    final wrapper = <String, dynamic>{
      'version': _backupVersion,
      'salt': salt,
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

      // Platform may not support saveFile; fall back to application documents dir.
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

  /// Import notes and encrypted media from a backup file during first-time setup.
  ///
  /// This method is used when no password has been set yet.
  /// The [restorePassword] is used to decrypt the backup file and will become the app password.
  /// Returns the number of notes restored.
  static Future<int> importEncryptedBackupFirstTime({
    required Uint8List fileBytes,
    required String restorePassword,
  }) async {
    await HiveDatabaseService.initialize();

    final decoded = jsonDecode(utf8.decode(fileBytes));
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Invalid backup format.');
    }

    final backupVersion = decoded['version'] as int?;
    if (backupVersion != _backupVersion) {
      throw FormatException('Unsupported backup version: $backupVersion');
    }

    final salt = decoded['salt'] as String?;
    final payload = decoded['payload'] as String?;
    if (salt == null || payload == null) {
      throw FormatException('Incomplete backup payload.');
    }

    // Decrypt the backup using the restore password and backup salt
    final decryptedJson = await CryptoService.decryptWithSalt(
      payload,
      restorePassword,
      salt,
    );

    final payloadMap = jsonDecode(decryptedJson);
    if (payloadMap is! Map<String, dynamic>) {
      throw FormatException('Invalid backup payload content.');
    }

    final notesData = payloadMap['notes'];
    final mediaData = payloadMap['media'];

    if (notesData is! List) {
      throw FormatException('Missing notes in backup payload.');
    }
    if (mediaData is! Map<String, dynamic>) {
      throw FormatException('Missing media in backup payload.');
    }

    // Parse the notes (they're already in the correct format from the backup)
    final restoredNotes = <Note>[];
    for (final item in notesData) {
      if (item is Map<String, dynamic>) {
        restoredNotes.add(Note.fromMap(item));
      } else if (item is Map) {
        restoredNotes.add(Note.fromMap(Map<String, dynamic>.from(item)));
      }
    }

    // Setup password with the backup's salt
    await CryptoService.importCryptoMetadata(saltBase64: salt);
    await CryptoService.setupPassword(restorePassword);
    HiveDatabaseService.setPassword(restorePassword);

    // Save all notes directly (they're already encrypted with the correct key)
    await HiveDatabaseService.replaceAllNotesRaw(restoredNotes);

    // Handle media files (they're already encrypted with the correct key)
    await MediaService.clearAllMedia();
    for (final entry in mediaData.entries) {
      final mediaId = entry.key;
      final value = entry.value;
      if (value is String) {
        final encryptedBytes = base64.decode(value);
        // Write encrypted bytes directly since they match the imported salt
        await MediaService.writeEncryptedMediaFile(mediaId, encryptedBytes);
      }
    }

    return restoredNotes.length;
  }

  /// Import notes and encrypted media from a previously exported backup file.
  ///
  /// The [restorePassword] is used to decrypt the backup file.
  /// The [currentPassword] is used to re-encrypt the notes with the existing app password.
  /// Returns the number of notes restored.
  static Future<int> importEncryptedBackup({
    required Uint8List fileBytes,
    required String restorePassword,
    required String currentPassword,
  }) async {
    await HiveDatabaseService.initialize();

    final decoded = jsonDecode(utf8.decode(fileBytes));
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Invalid backup format.');
    }

    final backupVersion = decoded['version'] as int?;
    if (backupVersion != _backupVersion) {
      throw FormatException('Unsupported backup version: $backupVersion');
    }

    final salt = decoded['salt'] as String?;
    final payload = decoded['payload'] as String?;
    if (salt == null || payload == null) {
      throw FormatException('Incomplete backup payload.');
    }

    // Step 1: Decrypt the backup using the restore password and backup salt
    final decryptedJson = await CryptoService.decryptWithSalt(
      payload,
      restorePassword,
      salt,
    );

    final payloadMap = jsonDecode(decryptedJson);
    if (payloadMap is! Map<String, dynamic>) {
      throw FormatException('Invalid backup payload content.');
    }

    final notesData = payloadMap['notes'];
    final mediaData = payloadMap['media'];

    if (notesData is! List) {
      throw FormatException('Missing notes in backup payload.');
    }
    if (mediaData is! Map<String, dynamic>) {
      throw FormatException('Missing media in backup payload.');
    }

    // Step 2: Parse the decrypted notes
    final restoredNotes = <Note>[];
    for (final item in notesData) {
      if (item is Map<String, dynamic>) {
        restoredNotes.add(Note.fromMap(item));
      } else if (item is Map) {
        restoredNotes.add(Note.fromMap(Map<String, dynamic>.from(item)));
      }
    }

    // Step 3: Decrypt note content with restore password, then re-encrypt with current password
    final reEncryptedNotes = <Note>[];
    for (final note in restoredNotes) {
      String decryptedContent = note.content;

      if (note.content.isNotEmpty) {
        try {
          // Decrypt with restore password using backup salt
          decryptedContent = await CryptoService.decryptWithSalt(
            note.content,
            restorePassword,
            salt,
          );
        } catch (e) {
          // If decryption fails, content might not be encrypted
          decryptedContent = note.content;
        }
      }

      // Re-encrypt with current password using current salt
      final reEncryptedContent = await CryptoService.encrypt(
        decryptedContent,
        currentPassword,
      );

      // Create new note with re-encrypted data
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

    // Step 4: Set the current password for database operations
    HiveDatabaseService.setPassword(currentPassword);

    // Step 5: Replace all notes with re-encrypted versions
    await HiveDatabaseService.replaceAllNotesRaw(reEncryptedNotes);

    // Step 6: Handle media files - decrypt with restore password, re-encrypt with current password
    await MediaService.clearAllMedia();
    for (final entry in mediaData.entries) {
      final mediaId = entry.key;
      final value = entry.value;
      if (value is String) {
        final encryptedBytes = base64.decode(value);

        // Decrypt media bytes with restore password using backup salt
        final decryptedMedia = await _decryptMediaBytesWithSalt(
          encryptedBytes,
          restorePassword,
          salt,
        );

        // Re-encrypt with current password using current salt
        final reEncryptedBytes = await _encryptMediaBytes(
          decryptedMedia,
          currentPassword,
        );

        // Write back with same mediaId to maintain references
        await MediaService.writeEncryptedMediaFile(mediaId, reEncryptedBytes);
      }
    }

    return restoredNotes.length;
  }

  static Future<Directory> _fallbackDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Decrypt media bytes using a specific salt (for backup restore)
  static Future<Uint8List> _decryptMediaBytesWithSalt(
    Uint8List encryptedBytes,
    String password,
    String saltBase64,
  ) async {
    if (encryptedBytes.isEmpty) return Uint8List(0);

    // Decrypt using the same logic as CryptoService but with provided salt
    final salt = base64.decode(saltBase64);
    final key = _deriveKeyFromPassword(password, salt);

    final iv = encryptedBytes.sublist(0, 16);
    final encryptedData = encryptedBytes.sublist(16);

    final encrypter = Encrypter(AES(Key(key)));
    final encrypted = Encrypted(encryptedData);
    final decryptedList = encrypter.decryptBytes(encrypted, iv: IV(iv));
    return Uint8List.fromList(decryptedList);
  }

  /// Encrypt media bytes with current password
  static Future<Uint8List> _encryptMediaBytes(
    Uint8List data,
    String password,
  ) async {
    if (data.isEmpty) return Uint8List(0);

    // Get current salt from CryptoService
    final saltMetadata = await CryptoService.exportCryptoMetadata();
    final saltBase64 = saltMetadata['salt'] ?? '';
    if (saltBase64.isEmpty) {
      throw Exception('Current encryption salt not found.');
    }

    final salt = base64.decode(saltBase64);
    final iv = _generateRandomBytes(16);
    final key = _deriveKeyFromPassword(password, salt);

    final encrypter = Encrypter(AES(Key(key)));
    final encrypted = encrypter.encryptBytes(data, iv: IV(iv));

    final combined = iv + encrypted.bytes;
    return Uint8List.fromList(combined);
  }

  /// Derive key from password (same as CryptoService)
  static Uint8List _deriveKeyFromPassword(String password, Uint8List salt) {
    const iterations = 10000;
    const keyLength = 32;

    List<int> passwordBytes = utf8.encode(password);
    var hmac = Hmac(sha256, passwordBytes);
    var key = List<int>.filled(keyLength, 0);
    var result = List<int>.from(salt);

    for (var i = 0; i < iterations; i++) {
      var hmacInput = List<int>.from(result);
      var mac = hmac.convert(hmacInput);
      result = mac.bytes;

      for (var j = 0; j < keyLength; j++) {
        key[j] ^= result[j % result.length];
      }
    }

    return Uint8List.fromList(key);
  }

  /// Generate random bytes for IV
  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
