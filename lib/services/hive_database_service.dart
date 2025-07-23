import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/services/encryption_isolate_service.dart';
import 'package:local_keep/services/note_object_pool.dart';

class HiveDatabaseService {
  static Box<Note>? _notesBox;
  static String?
  _encryptedPassword; // Store encrypted password instead of plain text
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

    if (_encryptedPassword == null) {
      throw Exception('Password not set for database access');
    }

    try {
      // Use password for Hive encryption
      final currentPassword = _getCurrentPassword();
      final encryptionKey = _deriveEncryptionKey(currentPassword);
      _notesBox = await Hive.openBox<Note>(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );

      return _notesBox!;
    } catch (e) {
      print('Error opening Hive box: $e');
      rethrow;
    }
  }

  // Set current password for cryptographic operations (store encrypted in memory)
  static Future<void> setPassword(String password) async {
    // Clear any existing password first
    _clearPassword();
    
    _encryptedPassword = await CryptoService.createMemoryEncryptedPassword(
      password,
    );
    
    // Clear the input parameter from local scope
    password = ''; // Help with garbage collection
  }

  // Clear password from memory
  static void _clearPassword() {
    if (_encryptedPassword != null) {
      _encryptedPassword = null;
      // Force some memory operations to help with cleanup
      final noise = List.generate(100, (_) => DateTime.now().toString());
      noise.clear();
    }
  }

  // Get the decrypted password when needed
  static String _getCurrentPassword() {
    if (_encryptedPassword == null) {
      throw Exception('Password not set for database access');
    }
    return CryptoService.decryptMemoryEncryptedPassword(_encryptedPassword!);
  }

  // Check if the password is set
  static bool get isPasswordSet => _encryptedPassword != null;

  // Insert a note with async encryption
  static Future<String> insertNote(Note note) async {
    if (_encryptedPassword == null) {
      throw Exception('Password not set for encryption');
    }

    try {
      final box = await _getNotesBox();

      // Generate a unique ID for the note
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Encrypt the note content before storing
      final currentPassword = _getCurrentPassword();
      final encryptedContent = await CryptoService.encrypt(
        note.content,
        currentPassword,
      );

      // Get the highest order_index efficiently
      int maxOrder = -1;
      if (box.isNotEmpty) {
        // Use Hive's efficient iteration
        maxOrder = box.values
            .map((n) => n.orderIndex)
            .reduce((a, b) => a > b ? a : b);
      }
      final orderIndex = maxOrder + 1;

      // Create note with encrypted content and ID
      final noteToStore = Note(
        id: id,
        content: encryptedContent,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        orderIndex: orderIndex,
      );

      await box.put(id, noteToStore);
      return id;
    } catch (e) {
      // Fallback to synchronous encryption
      print('Async encryption failed, falling back to sync: $e');
      return _insertNoteSync(note);
    }
  }

  // Fallback synchronous insert
  static Future<String> _insertNoteSync(Note note) async {
    final box = await _getNotesBox();
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final encryptedContent = await CryptoService.encrypt(
      note.content,
      _getCurrentPassword(),
    );

    int maxOrder = -1;
    if (box.isNotEmpty) {
      maxOrder = box.values
          .map((n) => n.orderIndex)
          .reduce((a, b) => a > b ? a : b);
    }
    final orderIndex = maxOrder + 1;

    final noteToStore = Note(
      id: id,
      content: encryptedContent,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      orderIndex: orderIndex,
    );

    await box.put(id, noteToStore);
    return id;
  }

  // Get all notes with optimized performance using isolates for encryption
  static Future<List<Note>> getNotes() async {
    if (_encryptedPassword == null) {
      throw Exception('Password not set for decryption');
    }

    if (!await CryptoService.isPasswordSetup()) {
      throw Exception('Password not properly initialized');
    }

    try {
      final box = await _getNotesBox();

      if (box.isEmpty) {
        return [];
      }

      final notes = <Note>[];
      final encryptedContents = <String>[];
      final noteMetadata = <Map<String, dynamic>>[];

      // First pass: collect encrypted content and metadata
      for (final note in box.values) {
        encryptedContents.add(note.content);
        noteMetadata.add({
          'id': note.id,
          'createdAt': note.createdAt,
          'updatedAt': note.updatedAt,
          'orderIndex': note.orderIndex,
        });
      }

      // Batch decrypt using isolate for better performance
      final decryptedContents = await EncryptionIsolateService.decryptBatch(
        encryptedContents,
        _getCurrentPassword(),
      );

      // Second pass: create note objects with decrypted content using object pool
      for (int i = 0; i < noteMetadata.length; i++) {
        final metadata = noteMetadata[i];
        final decryptedContent = decryptedContents[i];

        notes.add(
          NoteObjectPool.getNote(
            id: metadata['id'],
            content: decryptedContent,
            createdAt: metadata['createdAt'],
            updatedAt: metadata['updatedAt'],
            orderIndex: metadata['orderIndex'],
          ),
        );
      }

      // Sort by createdAt DESC (newest first)
      notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return notes;
    } catch (e) {
      // Fallback to sequential processing if batch fails
      print('Batch decryption failed, falling back to sequential: $e');
      return _getNotesSequential();
    }
  }

  // Fallback sequential method
  static Future<List<Note>> _getNotesSequential() async {
    final box = await _getNotesBox();
    final notes = <Note>[];

    for (final note in box.values) {
      try {
        final decryptedContent = await CryptoService.decrypt(
          note.content,
          _getCurrentPassword(),
        );

        notes.add(
          NoteObjectPool.getNote(
            id: note.id,
            content: decryptedContent,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            orderIndex: note.orderIndex,
          ),
        );
      } catch (e) {
        print('Error decrypting note ${note.id}: $e');
        continue;
      }
    }

    notes.sort((a, b) {
      final orderComparison = a.orderIndex.compareTo(b.orderIndex);
      if (orderComparison != 0) return orderComparison;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return notes;
  }

  // Update a note with async encryption
  static Future<int> updateNote(Note note) async {
    if (_encryptedPassword == null) {
      throw Exception('Password not set for encryption');
    }

    if (note.id == null) {
      throw Exception('Note ID cannot be null for update');
    }

    try {
      final box = await _getNotesBox();

      // Encrypt content using isolate for better performance
      final encryptedContent = await EncryptionIsolateService.encryptAsync(
        note.content,
        _getCurrentPassword(),
      );

      // Create updated note with encrypted content
      final updatedNote = Note(
        id: note.id,
        content: encryptedContent,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        orderIndex: note.orderIndex,
      );

      await box.put(note.id!, updatedNote);
      return 1; // Return 1 to match SQLite behavior
    } catch (e) {
      // Fallback to synchronous encryption
      print('Async encryption failed for update, falling back to sync: $e');
      return _updateNoteSync(note);
    }
  }

  // Fallback synchronous update
  static Future<int> _updateNoteSync(Note note) async {
    final box = await _getNotesBox();

    final encryptedContent = await CryptoService.encrypt(
      note.content,
      _getCurrentPassword(),
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
    try {
      final box = await _getNotesBox();
      await box.delete(id);
      return 1; // Return 1 to match SQLite behavior
    } catch (e) {
      throw Exception('Error deleting note: $e');
    }
  }

  // Clear all notes
  static Future<void> clearNotes() async {
    try {
      final box = await _getNotesBox();
      await box.clear();
    } catch (e) {
      throw Exception('Error clearing notes: $e');
    }
  }

  // Update note orders with batch operations for better performance
  static Future<void> updateNoteOrders(List<Note> notes) async {
    try {
      final box = await _getNotesBox();
      final batch = <String, Note>{};

      for (int i = 0; i < notes.length; i++) {
        final note = notes[i];
        if (note.id != null) {
          final existingNote = box.get(note.id!);
          if (existingNote != null && existingNote.orderIndex != i) {
            final updatedNote = Note(
              id: existingNote.id,
              content: existingNote.content, // Keep encrypted content
              createdAt: existingNote.createdAt,
              updatedAt: existingNote.updatedAt,
              orderIndex: i,
            );
            batch[note.id!] = updatedNote;
          }
        }
      }

      // Only update if there are changes
      if (batch.isNotEmpty) {
        await box.putAll(batch);
      }
    } catch (e) {
      throw Exception('Error updating note orders: $e');
    }
  }

  // Initialize order_index for existing notes (called after password is set)
  static Future<void> initializeNoteOrders() async {
    try {
      final box = await _getNotesBox();

      // Get all notes that have order_index = 0 and sort by updated_at DESC
      final unorderedNotes =
          box.values.where((note) => note.orderIndex == 0).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (unorderedNotes.isNotEmpty) {
        for (int i = 0; i < unorderedNotes.length; i++) {
          final note = unorderedNotes[i];
          if (note.id != null) {
            final updatedNote = Note(
              id: note.id,
              content: note.content,
              createdAt: note.createdAt,
              updatedAt: note.updatedAt,
              orderIndex: i,
            );
            await box.put(note.id!, updatedNote);
          }
        }
      }
    } catch (e) {
      throw Exception('Error initializing note orders: $e');
    }
  }

  // Re-encrypt all notes with a new password
  static Future<void> reEncryptNotes(
    String oldPassword,
    String newPassword,
  ) async {
    try {
      final box = await _getNotesBox();

      // First verify old password by trying to decrypt a note
      if (box.isNotEmpty) {
        final firstNote = box.values.first;
        final encryptedContent = firstNote.content;
        try {
          await CryptoService.decrypt(encryptedContent, oldPassword);
        } catch (e) {
          throw Exception('Invalid old password');
        }
      }

      // Re-encrypt all notes with new password
      for (final note in box.values) {
        if (note.id != null) {
          final encryptedContent = note.content;
          // Decrypt with old password
          final decryptedContent = await CryptoService.decrypt(
            encryptedContent,
            oldPassword,
          );
          // Encrypt with new password
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

      // Update current password
      await setPassword(newPassword);
    } catch (e) {
      throw Exception('Error re-encrypting notes: $e');
    }
  }

  // Close the box
  static Future<void> close() async {
    if (_notesBox != null && _notesBox!.isOpen) {
      await _notesBox!.close();
      _notesBox = null;
    }
    // Clear sensitive data when closing
    _clearPassword();
  }
}
