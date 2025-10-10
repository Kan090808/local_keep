import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/models/media_attachment.dart';
import 'package:local_keep/services/crypto_service.dart';

class HiveDatabaseService {
  static Box<Note>? _notesBox;
  static String? _currentPassword;
  static const String _boxName = 'notes_v2'; // Changed box name for fresh start
  static bool _isInitialized = false;

  /// Initialize Hive and register adapters
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      // Only register adapters if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(NoteAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(MediaAttachmentAdapter());
      }

      _isInitialized = true;
      print('✓ Hive initialized successfully');
    } catch (e) {
      print('✗ Error initializing Hive: $e');
      rethrow;
    }
  }

  /// Set password for encryption
  static void setPassword(String password) {
    _currentPassword = password;
    print('✓ Password set for database');
  }

  /// Get current password
  static String? getPassword() {
    return _currentPassword;
  }

  /// Derive encryption key from password
  static Uint8List _deriveEncryptionKey(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
  }

  /// Get or open the notes box
  static Future<Box<Note>> _getNotesBox() async {
    // Return existing box if already open
    if (_notesBox != null && _notesBox!.isOpen) {
      return _notesBox!;
    }

    // Check password is set
    if (_currentPassword == null) {
      throw Exception('Password not set. Call setPassword() first.');
    }

    try {
      // Generate encryption key
      final encryptionKey = _deriveEncryptionKey(_currentPassword!);

      // Open encrypted box
      _notesBox = await Hive.openBox<Note>(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );

      print('✓ Notes box opened (${_notesBox!.length} notes)');
      return _notesBox!;
    } catch (e) {
      print('✗ Error opening notes box: $e');

      // Handle corrupted database
      if (e.toString().contains('type') || e.toString().contains('adapt')) {
        print('⚠ Detected corrupted database, resetting...');
        await _resetDatabase();

        // Try again with fresh database
        final encryptionKey = _deriveEncryptionKey(_currentPassword!);
        _notesBox = await Hive.openBox<Note>(
          _boxName,
          encryptionCipher: HiveAesCipher(encryptionKey),
        );
        print('✓ Fresh database created');
        return _notesBox!;
      }

      rethrow;
    }
  }

  /// Reset database (delete and recreate)
  static Future<void> _resetDatabase() async {
    try {
      if (_notesBox?.isOpen == true) {
        await _notesBox!.close();
        _notesBox = null;
      }
      await Hive.deleteBoxFromDisk(_boxName);
      print('✓ Database reset complete');
    } catch (e) {
      print('✗ Error resetting database: $e');
    }
  }

  /// Insert a new note
  static Future<String> insertNote(Note note) async {
    try {
      // Get box
      final box = await _getNotesBox();

      // Generate unique ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Encrypt content
      final encryptedContent = await CryptoService.encrypt(
        note.content,
        _currentPassword!,
      );

      // Create note with encrypted content and media attachments
      final noteToStore = Note(
        id: id,
        content: encryptedContent,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        orderIndex: note.orderIndex,
        mediaAttachments: note.mediaAttachments, // Include media attachments
      );

      // Store in box
      await box.put(id, noteToStore);

      print(
        '✓ Note saved (ID: $id, length: ${note.content.length}, media: ${note.mediaAttachments.length})',
      );
      return id;
    } catch (e) {
      print('✗ Error saving note: $e');
      rethrow;
    }
  }

  /// Get all notes
  static Future<List<Note>> getNotes() async {
    try {
      final box = await _getNotesBox();
      final notes = <Note>[];

      for (final note in box.values) {
        try {
          // Decrypt content
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
              mediaAttachments:
                  note.mediaAttachments, // Include media attachments
            ),
          );
        } catch (e) {
          print('⚠ Skipping corrupted note ${note.id}: $e');
          continue;
        }
      }

      // Sort by date (newest first)
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✓ Loaded ${notes.length} notes');
      return notes;
    } catch (e) {
      print('✗ Error loading notes: $e');
      rethrow;
    }
  }

  /// Update an existing note
  static Future<void> updateNote(Note note) async {
    if (note.id == null) {
      throw Exception('Cannot update note without ID');
    }

    try {
      final box = await _getNotesBox();

      // Encrypt updated content
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
        mediaAttachments: note.mediaAttachments, // Include media attachments
      );

      await box.put(note.id!, updatedNote);
      print(
        '✓ Note updated (ID: ${note.id}, media: ${note.mediaAttachments.length})',
      );
    } catch (e) {
      print('✗ Error updating note: $e');
      rethrow;
    }
  }

  /// Delete a note
  static Future<void> deleteNote(String id) async {
    try {
      final box = await _getNotesBox();
      await box.delete(id);
      print('✓ Note deleted (ID: $id)');
    } catch (e) {
      print('✗ Error deleting note: $e');
      rethrow;
    }
  }

  /// Clear all notes
  static Future<void> clearNotes() async {
    try {
      final box = await _getNotesBox();
      await box.clear();
      print('✓ All notes cleared');
    } catch (e) {
      print('✗ Error clearing notes: $e');
      rethrow;
    }
  }

  /// Re-encrypt all notes with new password
  static Future<void> reEncryptNotes(
    String oldPassword,
    String newPassword,
  ) async {
    try {
      final box = await _getNotesBox();
      int count = 0;

      for (final note in box.values) {
        if (note.id != null) {
          // Decrypt with old password
          final decryptedContent = await CryptoService.decrypt(
            note.content,
            oldPassword,
          );

          // Re-encrypt with new password
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
            mediaAttachments:
                note.mediaAttachments, // Include media attachments
          );

          await box.put(note.id!, updatedNote);
          count++;
        }
      }

      setPassword(newPassword);
      print('✓ Re-encrypted $count notes');
    } catch (e) {
      print('✗ Error re-encrypting notes: $e');
      rethrow;
    }
  }

  /// Close the database
  static Future<void> close() async {
    if (_notesBox?.isOpen == true) {
      await _notesBox!.close();
      _notesBox = null;
    }
    _currentPassword = null;
    print('✓ Database closed');
  }

  /// Force reset database (manual cleanup)
  static Future<void> resetDatabase() async {
    try {
      print('⚠ Resetting database...');

      // Close box if open
      if (_notesBox?.isOpen == true) {
        await _notesBox!.close();
        _notesBox = null;
      }

      // Delete the box from disk
      await Hive.deleteBoxFromDisk(_boxName);
      print('✓ Database reset complete');
    } catch (e) {
      print('✗ Error resetting database: $e');
      rethrow;
    }
  }
}
