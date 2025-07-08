import 'package:flutter/foundation.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/database_service.dart';

class NoteProvider with ChangeNotifier {
  List<Note> _notes = [];
  
  List<Note> get notes => [..._notes];
  
  Future<void> fetchNotes() async {
    try {
      // Initialize note orders for migrated databases
      await DatabaseService.initializeNoteOrders();
      _notes = await DatabaseService.getNotes();
      notifyListeners();
    } catch (e) {
      print('Error fetching notes: $e');
      _notes = [];
      notifyListeners();
    }
  }
  
  Future<void> addNote(String content) async {
    try {
      final newNote = Note.create(content: content);
      final id = await DatabaseService.insertNote(newNote);
      final updatedNote = newNote.copyWith(id: id);
      _notes.insert(0, updatedNote);
      notifyListeners();
    } catch (e) {
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
      await DatabaseService.updateNote(updatedNote);
      
      final noteIndex = _notes.indexWhere((n) => n.id == note.id);
      if (noteIndex >= 0) {
        _notes[noteIndex] = updatedNote;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating note: $e');
      rethrow;
    }
  }
  
  Future<void> deleteNote(int id) async {
    await DatabaseService.deleteNote(id);
    _notes.removeWhere((note) => note.id == id);
    notifyListeners();
  }
  
  Note? getNoteById(int id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (_) {
      return null;
    }
  }
  
  int get noteCount => _notes.length;
  
  void clearNotes() {
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
      final Note item = _notes.removeAt(oldIndex);
      _notes.insert(newIndex, item);

      // Update the order in persistent storage
      await DatabaseService.updateNoteOrders(_notes);

      notifyListeners();
    } catch (e) {
      // Revert to original state on error
      _notes = originalNotes;
      notifyListeners();
      rethrow;
    }
  }
}