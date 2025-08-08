import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/services/hive_database_service.dart';

class BackupService {
  // Export current notes as encrypted JSON and let user choose save location
  static Future<bool> exportEncrypted(String password) async {
    // Get decrypted notes payload
    final notes = await HiveDatabaseService.getNotes();
    final cryptoMeta = await CryptoService.exportCryptoMetadata();
    final contentPayload = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'notes': notes.map((n) => n.toMap()).toList(),
    };

    // Encrypt content
    final jsonStr = jsonEncode(contentPayload);
    final encryptedPayload = await CryptoService.encrypt(jsonStr, password);

    // Wrap with salt (unencrypted) so import can derive key cross-device
    final wrapper = jsonEncode({
      'version': 1,
      'salt': cryptoMeta['salt'],
      'payload': encryptedPayload,
    });

    // Save as .lkeep file
    final bytes = Uint8List.fromList(utf8.encode(wrapper));
    final fileName =
        'local_keep_backup_${DateTime.now().millisecondsSinceEpoch}.lkeep';

    final savedPath = await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      ext: 'lkeep',
      mimeType: MimeType.text,
    );

    // On web, saveFile returns a web url, on desktop/mobile, a path
    return savedPath.toString().isNotEmpty;
  }

  // Import from user-selected encrypted backup file
  static Future<bool> importEncrypted(String password) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lkeep', 'txt', 'json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return false;

    final file = result.files.first;
    final contentBytes = file.bytes;
    if (contentBytes == null) return false;

    return importEncryptedFromBytes(contentBytes, password);
  }

  // Import from already-selected file bytes
  static Future<bool> importEncryptedFromBytes(
    Uint8List contentBytes,
    String password,
  ) async {
    try {
      // Read wrapper JSON from file
      final wrapperStr = utf8.decode(contentBytes);
      final wrapper = jsonDecode(wrapperStr) as Map<String, dynamic>;
      final salt = (wrapper['salt'] as String?) ?? '';
      final payloadBase64 = (wrapper['payload'] as String?) ?? '';
      if (salt.isEmpty || payloadBase64.isEmpty) return false;

      // Decrypt content payload using provided salt (backup password)
      final decrypted = await CryptoService.decryptWithSalt(
        payloadBase64,
        password,
        salt,
      );
      final decoded = jsonDecode(decrypted) as Map<String, dynamic>;

      final notesList =
          (decoded['notes'] as List<dynamic>).cast<Map<String, dynamic>>();
      // Insert/replace notes — DB layer will re-encrypt with current app password
      for (final m in notesList) {
        final note = Note.fromMap(m);
        if (note.id == null) {
          await HiveDatabaseService.insertNote(note);
        } else {
          // Try update existing or insert new
          try {
            await HiveDatabaseService.updateNote(note);
          } catch (_) {
            await HiveDatabaseService.insertNote(note);
          }
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
