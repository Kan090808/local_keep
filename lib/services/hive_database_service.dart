import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/crypto_service.dart';

class HiveDatabaseService {
  static Box<Note>? _notesBox;
  static String? _currentPassword;
  static const String _boxName = 'notes';
  static bool _isInitialized = false;

  // Initialize Hive
  static Future<void> initialize() async {
    if (!_isInitialized) {
      await Hive.initFlutter();
      Hive.registerAdapter(NoteAdapter());
      _isInitialized = true;
    }
  }

  // Derive encryption key from password for Hive
  static Uint8List _deriveEncryptionKey(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
  }

  // Open encrypted box with password
  static Future<Box<Note>> _getNotesBox() async {
    if (_notesBox != null && _notesBox!.isOpen) {
      return _notesBox!;
    }

    if (_currentPassword == null) {
      throw Exception('Password not set for database access');
    }

    final encryptionKey = _deriveEncryptionKey(_currentPassword!);
    _notesBox = await Hive.openBox<Note>(
      _boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    return _notesBox!;
  }

  // Set current password
  static void setPassword(String password) {
    _currentPassword = password;
  }

  // Insert a note
  static Future<String> insertNote(Note note) async {
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
      orderIndex: 0,
    );

    await box.put(id, noteToStore);
    return id;
  }

  // Get all notes
  static Future<List<Note>> getNotes() async {
    final box = await _getNotesBox();
    final notes = <Note>[];

    for (final note in box.values) {
      try {
        final decryptedContent = await CryptoService.decrypt(
          note.content,
          _currentPassword!,
        );

        notes.add(Note(
          id: note.id,
          content: decryptedContent,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          orderIndex: note.orderIndex,
        ));
      } catch (e) {
        print('Error decrypting note ${note.id}: $e');
        continue;
      }
    }

    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }

  // Update a note
  static Future<int> updateNote(Note note) async {
    if (note.id == null) {
      throw Exception('Note ID cannot be null for update');
    }

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
    );

    await box.put(note.id!, updatedNote);
    return 1;
  }

  // Delete a note
  static Future<int> deleteNote(String id) async {
    final box = await _getNotesBox();
    await box.delete(id);
    return 1;
  }

  // Clear all notes
  static Future<void> clearNotes() async {
    final box = await _getNotesBox();
    await box.clear();
  }

  // Re-encrypt all notes with a new password
  static Future<void> reEncryptNotes(
    String oldPassword,
    String newPassword,
  ) async {
    final box = await _getNotesBox();

    for (final note in box.values) {
      if (note.id != null) {
        final decryptedContent = await CryptoService.decrypt(
          note.content,
          oldPassword,
        );
        final reEncryptedContent = await CryptoService.encrypt(
          decryptedContent,
          newPassword,
        );

        final updatedNote = Note(
          id: note.id,
          content: reEncryptedContent,
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
          orderIndex: note.orderIndex,
        );

        await box.put(note.id!, updatedNote);
      }
    }

    setPassword(newPassword);
  }

  // Close the box
  static Future<void> close() async {
    if (_notesBox != null && _notesBox!.isOpen) {
      await _notesBox!.close();
      _notesBox = null;
    }
    _currentPassword = null;
  }
}
