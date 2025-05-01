import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/crypto_service.dart';

class DatabaseService {
  static Database? _database;
  static String? _currentPassword;
  
  // Initialize database
  static Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDatabase();
    return _database!;
  }
  
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'local_keep.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
      },
    );
  }
  
  // Set current password for cryptographic operations
  static void setPassword(String password) {
    _currentPassword = password;
  }
  
  // Check if the password is set
  static bool get isPasswordSet => _currentPassword != null;
  
  // Insert a note
  static Future<int> insertNote(Note note) async {
    if (_currentPassword == null) {
      throw Exception('Password not set for encryption');
    }
    
    final db = await database;
    final noteMap = note.toMap();
    
    // Encrypt content
    noteMap['content'] = await CryptoService.encrypt(note.content, _currentPassword!);
    
    final result = await db.insert('notes', noteMap);
    if (result != 0) {
      print('Note inserted successfully with id: $result');
    } else {
      print('Failed to insert note');
    }
    return result;
  }
  
  // Get all notes
  static Future<List<Note>> getNotes() async {
    // final testString = "1";
    // final password = "kan090808";
    // final encrypted = await CryptoService.encrypt(testString, password);
    // final decrypted = await CryptoService.decrypt(encrypted, password);
    // print('Original test: $testString');
    // print('Encrypted test: $encrypted');
    // print('Decrypted test: $decrypted');

    if (_currentPassword == null) {
      throw Exception('Password not set for decryption');
    }

    if (!await CryptoService.isPasswordSetup()) {  // Add this check
      throw Exception('Password not properly initialized');
    }
    
    final db = await database;
    final maps = await db.query('notes', orderBy: 'updated_at DESC');
    final notes = <Note>[];
    for (var map in maps) {
      // Decrypt content
      final encryptedContent = map['content'] as String;
      final decryptedContent = await CryptoService.decrypt(encryptedContent, _currentPassword!);
      
      notes.add(Note.fromMap({
        ...map,
        'content': decryptedContent,
      }));
    }
    
    return notes;
  }
  
  // Update a note
  static Future<int> updateNote(Note note) async {
    if (_currentPassword == null) {
      throw Exception('Password not set for encryption');
    }
    
    final db = await database;
    final noteMap = note.toMap();
    
    // Encrypt content
    noteMap['content'] = await CryptoService.encrypt(note.content, _currentPassword!);
    
    return await db.update(
      'notes',
      noteMap,
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }
  
  // Delete a note
  static Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // Clear all notes
  static Future<void> clearNotes() async {
    final db = await database;
    await db.delete('notes');
  }

  // Re-encrypt all notes with a new password
  static Future<void> reEncryptNotes(String oldPassword, String newPassword) async {
    final db = await database;
    final maps = await db.query('notes');
    
    // First verify old password by trying to decrypt a note
    if (maps.isNotEmpty) {
      final firstNote = maps.first;
      final encryptedContent = firstNote['content'] as String;
      try {
        await CryptoService.decrypt(encryptedContent, oldPassword);
      } catch (e) {
        throw Exception('Invalid old password');
      }
    }
    
    // Re-encrypt all notes with new password
    for (var map in maps) {
      final encryptedContent = map['content'] as String;
      // Decrypt with old password
      final decryptedContent = await CryptoService.decrypt(encryptedContent, oldPassword);
      // Encrypt with new password
      final reEncryptedContent = await CryptoService.encrypt(decryptedContent, newPassword);
      
      await db.update(
        'notes',
        {'content': reEncryptedContent},
        where: 'id = ?',
        whereArgs: [map['id']],
      );
    }
    
    // Update current password
    _currentPassword = newPassword;
  }
}