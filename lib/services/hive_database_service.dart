import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/models/media_attachment.dart';
import 'package:local_keep/services/app_logger.dart';
import 'package:local_keep/services/crypto_service.dart';

class HiveDatabaseService {
  static Box<Note>? _notesBox;
  static String? _currentPassword;

  /// Current encrypted box (Hive key = PBKDF2-derived v2 subkey).
  static const String notesBoxName = 'notes_v3';

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(NoteAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(MediaAttachmentAdapter());
      }

      _isInitialized = true;
      AppLogger.d('Hive initialized');
    } catch (e) {
      AppLogger.e('Hive init failed', e);
      rethrow;
    }
  }

  static String? getPassword() => _currentPassword;

  static Future<Uint8List> _hiveKeyForPassword(String password) async {
    final salt = await CryptoService.readSalt();
    if (salt == null) {
      // Brand-new install path: salt created during setupPassword.
      final created = await CryptoService.getOrCreateSalt();
      final master = CryptoService.deriveMasterKeyV2(password, created);
      return CryptoService.hiveKeyV2(master);
    }

    final master = CryptoService.deriveMasterKeyV2(password, salt);
    return CryptoService.hiveKeyV2(master);
  }

  /// Open the current encrypted box for [password].
  static Future<void> ensureOpen(String password) async {
    _currentPassword = password;

    if (_notesBox != null && _notesBox!.isOpen) {
      return;
    }

    await initialize();

    final boxName = notesBoxName;
    final key = await _hiveKeyForPassword(password);
    _notesBox = await Hive.openBox<Note>(
      boxName,
      encryptionCipher: HiveAesCipher(key),
    );
    AppLogger.d('Opened notes box $boxName');
  }

  static Future<Box<Note>> _getNotesBox() async {
    if (_notesBox != null && _notesBox!.isOpen) {
      return _notesBox!;
    }
    if (_currentPassword == null) {
      throw Exception('Password not set. Call ensureOpen first.');
    }
    await ensureOpen(_currentPassword!);
    return _notesBox!;
  }

  static Future<String> insertNote(Note note) async {
    try {
      final box = await _getNotesBox();
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      final encryptedContent = await CryptoService.encrypt(
        note.content,
        _currentPassword!,
      );

      final noteToStore = Note(
        id: id,
        content: encryptedContent,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        orderIndex: note.orderIndex,
        mediaAttachments: note.mediaAttachments,
      );

      await box.put(id, noteToStore);
      AppLogger.d('Note saved id=$id');
      return id;
    } catch (e) {
      AppLogger.e('Error saving note', e);
      rethrow;
    }
  }

  static Future<List<Note>> getNotes() async {
    try {
      final box = await _getNotesBox();
      final notes = <Note>[];

      for (final note in box.values) {
        try {
          final decryptedContent = await CryptoService.decrypt(
            note.content,
            _currentPassword!,
          );

          notes.add(
            Note(
              id: note.id,
              content: decryptedContent,
              createdAt: note.createdAt,
              updatedAt: note.updatedAt,
              orderIndex: note.orderIndex,
              mediaAttachments: note.mediaAttachments,
            ),
          );
        } catch (e) {
          AppLogger.e('Skipping corrupted note ${note.id}', e);
          continue;
        }
      }

      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      AppLogger.d('Loaded ${notes.length} notes');
      return notes;
    } catch (e) {
      AppLogger.e('Error loading notes', e);
      rethrow;
    }
  }

  static Future<List<Note>> getNotesRaw() async {
    final box = await _getNotesBox();
    return List<Note>.from(box.values);
  }

  static Future<void> updateNote(Note note) async {
    if (note.id == null) {
      throw Exception('Cannot update note without ID');
    }

    try {
      final box = await _getNotesBox();
      final encryptedContent = await CryptoService.encrypt(
        note.content,
        _currentPassword!,
      );

      final updatedNote = Note(
        id: note.id,
        content: encryptedContent,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        orderIndex: note.orderIndex,
        mediaAttachments: note.mediaAttachments,
      );

      await box.put(note.id!, updatedNote);
      AppLogger.d('Note updated id=${note.id}');
    } catch (e) {
      AppLogger.e('Error updating note', e);
      rethrow;
    }
  }

  static Future<void> deleteNote(String id) async {
    try {
      final box = await _getNotesBox();
      await box.delete(id);
      AppLogger.d('Note deleted id=$id');
    } catch (e) {
      AppLogger.e('Error deleting note', e);
      rethrow;
    }
  }

  static Future<void> replaceAllNotesRaw(List<Note> notes) async {
    final box = await _getNotesBox();
    final Map<String, Note> entries = {};
    for (final note in notes) {
      if (note.id != null) {
        entries[note.id!] = note;
      }
    }

    final current = List<Note>.from(box.values);
    Future<void> apply(List<Note> values) async {
      final target = {for (final note in values) note.id!: note};
      if (target.isNotEmpty) {
        await box.putAll(target);
      }
      for (final key in box.keys.toList()) {
        if (!target.containsKey(key)) {
          await box.delete(key);
        }
      }
    }

    try {
      await apply(entries.values.toList());
    } catch (_) {
      await apply(current);
      rethrow;
    }

    AppLogger.d('Replaced notes count=${entries.length}');
  }

  static Future<void> clearNotes() async {
    try {
      final box = await _getNotesBox();
      await box.clear();
      AppLogger.d('All notes cleared');
    } catch (e) {
      AppLogger.e('Error clearing notes', e);
      rethrow;
    }
  }

  /// Re-encrypt all notes + media and re-key Hive for a password change.
  static Future<void> reEncryptAll(
    String oldPassword,
    String newPassword,
  ) async {
    await ensureOpen(oldPassword);

    final notes = await getNotesRaw();
    final salt = await CryptoService.readSalt();
    if (salt == null) {
      throw StateError('Salt missing during password change.');
    }
    final reEncryptedNotes = <Note>[];
    for (final note in notes) {
      if (note.id == null) continue;
      final plain =
          note.content.isEmpty
              ? ''
              : await CryptoService.decrypt(note.content, oldPassword);
      final cipher =
          plain.isEmpty ? '' : await CryptoService.encrypt(plain, newPassword);
      reEncryptedNotes.add(
        Note(
          id: note.id,
          content: cipher,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          orderIndex: note.orderIndex,
          mediaAttachments: note.mediaAttachments,
        ),
      );
    }

    // Media re-encrypt via MediaService seam (imported lazily by caller path).
    // Implemented here through dynamic import avoidance: caller also updates media.
    await replaceAllNotesRaw(reEncryptedNotes);

    // Close and reopen under new hive key in v2 box.
    final plainNotesForMove = List<Note>.from(reEncryptedNotes);
    await _closeBoxOnly();

    final master = CryptoService.deriveMasterKeyV2(newPassword, salt);
    final newHiveKey = CryptoService.hiveKeyV2(master);

    // Replace the current box with one encrypted by the new password.
    if (await Hive.boxExists(notesBoxName)) {
      await Hive.deleteBoxFromDisk(notesBoxName);
    }

    _notesBox = await Hive.openBox<Note>(
      notesBoxName,
      encryptionCipher: HiveAesCipher(newHiveKey),
    );
    _currentPassword = newPassword;

    if (plainNotesForMove.isNotEmpty) {
      final map = {
        for (final n in plainNotesForMove)
          if (n.id != null) n.id!: n,
      };
      await _notesBox!.putAll(map);
    }

    AppLogger.d(
      'Re-encrypted ${reEncryptedNotes.length} notes for new password',
    );
  }

  static Future<void> _closeBoxOnly() async {
    if (_notesBox?.isOpen == true) {
      await _notesBox!.close();
    }
    _notesBox = null;
  }

  static Future<void> close() async {
    await _closeBoxOnly();
    _currentPassword = null;
    AppLogger.d('Database closed');
  }

  static Future<void> resetDatabase() async {
    try {
      AppLogger.d('Resetting database');
      await _closeBoxOnly();
      if (await Hive.boxExists(notesBoxName)) {
        await Hive.deleteBoxFromDisk(notesBoxName);
      }
      AppLogger.d('Database reset complete');
    } catch (e) {
      AppLogger.e('Error resetting database', e);
      rethrow;
    }
  }
}
