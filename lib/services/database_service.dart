import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/crypto_service.dart';

class DatabaseService {
  static Database? _database;
  static String? _currentPassword;
  
  // Initialize database
  static Future<Database> get database async {
    if (_database != null) {
      print('Returning existing database instance');
      return _database!;
    }
    
    print('Initializing new database instance...');
    _database = await _initDatabase();
    print('Database initialized successfully');
    return _database!;
  }
  
  static Future<Database> _initDatabase() async {
    try {
      print('Getting database path...');
      final dbPath = await getDatabasesPath();
      print('Database path obtained: $dbPath');
      
      final path = join(dbPath, 'local_keep.db');
      print('Full database path: $path');
      
      print('Initializing database at path: $path');
      
      return await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          print('Creating database tables...');
          await db.execute('''
            CREATE TABLE notes(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              content TEXT,
              created_at TEXT,
              updated_at TEXT,
              order_index INTEGER DEFAULT 0
            )
          ''');
          print('Database tables created successfully');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('Upgrading database from version $oldVersion to $newVersion');
          if (oldVersion < 2) {
            // Safe migration - just add column with default values
            await db.execute('ALTER TABLE notes ADD COLUMN order_index INTEGER DEFAULT 0');
            print('Added order_index column to notes table');
            // Don't try to set specific orders until after password is entered
            // The order will be set when notes are first loaded
          }
        },
      );
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }
  
  // Set current password for cryptographic operations
  static void setPassword(String password) {
    _currentPassword = password;
  }
  
  // Check if the password is set
  static bool get isPasswordSet => _currentPassword != null;
  
  // Insert a note
  static Future<int> insertNote(Note note) async {
    print('InsertNote called with note: ${note.content}');
    
    if (_currentPassword == null) {
      throw Exception('Password not set for encryption');
    }
    
    try {
      print('Getting database instance...');
      final db = await database;
      print('Database instance obtained successfully');
      
      final noteMap = note.toMap();
      print('Note map created: $noteMap');
      
      // Encrypt content
      print('Encrypting content...');
      noteMap['content'] = await CryptoService.encrypt(note.content, _currentPassword!);
      print('Content encrypted successfully');
      
      // Get the highest order_index and add 1 (more efficient than updating all notes)
      print('Getting max order index...');
      final maxOrderResult = await db.rawQuery('SELECT MAX(order_index) as max_order FROM notes');
      final maxOrder = maxOrderResult.first['max_order'] as int? ?? -1;
      noteMap['order_index'] = maxOrder + 1;
      print('Order index set to: ${noteMap['order_index']}');
      
      print('Inserting note into database...');
      final result = await db.insert('notes', noteMap);
      if (result != 0) {
        print('Note inserted successfully with id: $result');
      } else {
        print('Failed to insert note');
      }
      return result;
    } catch (e) {
      print('Error inserting note: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
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
    final maps = await db.query('notes', orderBy: 'order_index DESC');
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

  // Update note orders
  static Future<void> updateNoteOrders(List<Note> notes) async {
    final db = await database;
    final batch = db.batch();
    
    for (int i = 0; i < notes.length; i++) {
      batch.update(
        'notes',
        {'order_index': i},
        where: 'id = ?',
        whereArgs: [notes[i].id],
      );
    }
    
    await batch.commit();
  }

  // Initialize order_index for existing notes (called after password is set)
  static Future<void> initializeNoteOrders() async {
    final db = await database;
    
    // Check if any notes have uninitialized order_index
    final unorderedNotes = await db.query(
      'notes',
      where: 'order_index = 0',
      orderBy: 'updated_at DESC',
    );
    
    if (unorderedNotes.isNotEmpty) {
      final batch = db.batch();
      for (int i = 0; i < unorderedNotes.length; i++) {
        batch.update(
          'notes',
          {'order_index': i},
          where: 'id = ?',
          whereArgs: [unorderedNotes[i]['id']],
        );
      }
      await batch.commit();
    }
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