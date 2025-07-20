import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/hive_database_service.dart';
import 'package:local_keep/services/smart_debounce_service.dart';
import 'package:local_keep/services/note_object_pool.dart';

class NoteProvider with ChangeNotifier {
  List<Note> _notes = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  Timer? _debounceReorderTimer;

  // Cache the last fetch time to avoid unnecessary database calls
  DateTime? _lastFetchTime;
  static const Duration _cacheTimeout = Duration(seconds: 30);

  List<Note> get notes => [..._notes];
  bool get isLoading => _isLoading;

  Future<void> fetchNotes({bool forceRefresh = false}) async {
    // Check if we need to refresh based on cache timeout
    if (!forceRefresh &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheTimeout &&
        _notes.isNotEmpty) {
      return; // Use cached data
    }

    // Don't set loading if we already have cached notes (better UX)
    bool shouldNotifyLoading = false;
    if (_notes.isEmpty) {
      _isLoading = true;
      shouldNotifyLoading = true;
    }

    try {
      // Initialize note orders for migrated databases
      await HiveDatabaseService.initializeNoteOrders();
      final newNotes = await HiveDatabaseService.getNotes();

      // Only update if there are actual changes
      if (!_areNotesEqual(_notes, newNotes)) {
        // Return old notes to pool before replacing
        NoteObjectPool.returnNotes(_notes);
        _notes = newNotes;
        _lastFetchTime = DateTime.now();
        notifyListeners(); // Safe to call here as we're not in build phase
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching notes: $e');
      if (_notes.isEmpty) {
        _notes = [];
        notifyListeners(); // Safe to call here
      }
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners(); // Safe to call here
      }
    }

    // Notify for loading state if needed
    if (shouldNotifyLoading) {
      notifyListeners(); // Safe to call here
    }
  }

  // Helper method to compare notes lists efficiently
  bool _areNotesEqual(List<Note> list1, List<Note> list2) {
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id ||
          list1[i].content != list2[i].content ||
          list1[i].updatedAt != list2[i].updatedAt ||
          list1[i].orderIndex != list2[i].orderIndex) {
        return false;
      }
    }
    return true;
  }

  Future<void> addNote(String content) async {
    try {
      final newNote = Note.create(content: content);

      // Optimistically add to UI first for better UX
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      final tempNote = newNote.copyWith(id: tempId);

      // Insert at the beginning for better UX (newest first)
      _notes.insert(0, tempNote);
      notifyListeners();

      // Save to database in background
      final actualId = await HiveDatabaseService.insertNote(newNote);

      // Update with actual ID
      final finalNote = newNote.copyWith(id: actualId);
      _notes[0] = finalNote; // Replace the temp note

      // No need to notify listeners again since the change is minimal
    } catch (e) {
      // Remove the optimistically added note on error
      if (_notes.isNotEmpty && _notes[0].content == content) {
        _notes.removeAt(0);
        notifyListeners();
      }
      print('Error adding note: $e');
      rethrow;
    }
  }

  Future<void> updateNote(Note note, String content) async {
    try {
      final updatedNote = note.copyWith(
        content: content,
        updatedAt: DateTime.now(),
      );

      // Update local state immediately for better UX
      final noteIndex = _notes.indexWhere((n) => n.id == note.id);
      if (noteIndex >= 0) {
        _notes[noteIndex] = updatedNote;
        notifyListeners();
      }

      // Update database
      await HiveDatabaseService.updateNote(updatedNote);
    } catch (e) {
      print('Error updating note: $e');
      // Optionally refresh from database on error
      await fetchNotes();
      rethrow;
    }
  }

  // Optimized debounced update with smart priority queuing
  void updateNoteDebounced(Note note, String content) {
    // Update UI immediately but intelligently
    final updatedNote = note.copyWith(
      content: content,
      updatedAt: DateTime.now(),
    );

    final noteIndex = _notes.indexWhere((n) => n.id == note.id);
    if (noteIndex >= 0) {
      _notes[noteIndex] = updatedNote;

      // Only notify listeners for significant changes to reduce rebuilds
      if (_shouldNotifyForContent(note.content, content)) {
        SmartDebounceService.debounce(
          key: 'ui_update_${note.id}',
          priority: OperationPriority.high,
          operation: () => notifyListeners(),
        );
      }
    }

    // Debounce database save with medium priority
    SmartDebounceService.debounce(
      key: 'save_${note.id}',
      priority: OperationPriority.medium,
      operation: () => _saveNoteToDatabase(note, content),
    );
  }

  // Separate method for database operations with error recovery
  Future<void> _saveNoteToDatabase(Note note, String content) async {
    try {
      final updatedNote = note.copyWith(
        content: content,
        updatedAt: DateTime.now(),
      );

      await HiveDatabaseService.updateNote(updatedNote);

      // Update the cached note with the final version
      final noteIndex = _notes.indexWhere((n) => n.id == note.id);
      if (noteIndex >= 0) {
        _notes[noteIndex] = updatedNote;
      }
    } catch (e) {
      print('Error saving note to database: $e');

      // Show error to user but don't block UI
      SmartDebounceService.debounce(
        key: 'error_notification',
        priority: OperationPriority.high,
        operation: () {
          // You can add error handling here, like showing a snackbar
          print('Failed to save note: $e');
        },
      );
    }
  }

  // Helper method to determine if UI should update for content changes
  bool _shouldNotifyForContent(String oldContent, String newContent) {
    // Only notify for significant changes (more than 5 characters difference)
    // or when crossing certain boundaries (empty to non-empty, etc.)
    if (oldContent.isEmpty != newContent.isEmpty) return true;
    if ((oldContent.length - newContent.length).abs() > 5) return true;
    if (oldContent.length % 50 != newContent.length % 50) {
      return true; // Every 50 chars
    }
    return false;
  }

  Future<void> deleteNote(String id) async {
    await HiveDatabaseService.deleteNote(id);
    _notes.removeWhere((note) => note.id == id);
    notifyListeners();
  }

  Note? getNoteById(String id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (_) {
      return null;
    }
  }

  int get noteCount => _notes.length;

  void clearNotes() {
    // Return notes to pool before clearing
    NoteObjectPool.returnNotes(_notes);
    _notes = [];
    notifyListeners();
  }

  Future<void> reorderNotes(int oldIndex, int newIndex) async {
    // Adjust index if item is moved downwards
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Store original state in case we need to revert
    final originalNotes = List<Note>.from(_notes);

    try {
      // Update UI immediately
      final Note item = _notes.removeAt(oldIndex);
      _notes.insert(newIndex, item);
      notifyListeners();

      // Update the order in persistent storage with debouncing
      _debounceReorderTimer?.cancel();
      _debounceReorderTimer = Timer(
        const Duration(milliseconds: 300),
        () async {
          try {
            await HiveDatabaseService.updateNoteOrders(_notes);
          } catch (e) {
            // Revert on error
            _notes = originalNotes;
            notifyListeners();
            rethrow;
          }
        },
      );
    } catch (e) {
      // Revert to original state on error
      _notes = originalNotes;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _debounceReorderTimer?.cancel();
    super.dispose();
  }
}
