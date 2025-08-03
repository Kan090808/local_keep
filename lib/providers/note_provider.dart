import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/hive_database_service.dart';

class NoteProvider with ChangeNotifier {
  List<Note> _notes = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  List<Note> get notes => [..._notes];
  bool get isLoading => _isLoading;

  Future<void> fetchNotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notes = await HiveDatabaseService.getNotes();
    } catch (e) {
      print('Error fetching notes: $e');
      _notes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNote(String content, {NoteType type = NoteType.text}) async {
    try {
      final newNote = Note.create(content: content, type: type);
      final id = await HiveDatabaseService.insertNote(newNote);
      final finalNote = newNote.copyWith(id: id);

      _notes.insert(0, finalNote);
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

      final noteIndex = _notes.indexWhere((n) => n.id == note.id);
      if (noteIndex >= 0) {
        _notes[noteIndex] = updatedNote;
        notifyListeners();
      }

      await HiveDatabaseService.updateNote(updatedNote);
    } catch (e) {
      print('Error updating note: $e');
      await fetchNotes();
      rethrow;
    }
  }

  void updateNoteDebounced(Note note, String content) {
    final updatedNote = note.copyWith(
      content: content,
      updatedAt: DateTime.now(),
    );

    final noteIndex = _notes.indexWhere((n) => n.id == note.id);
    if (noteIndex >= 0) {
      _notes[noteIndex] = updatedNote;
      notifyListeners();
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      HiveDatabaseService.updateNote(updatedNote);
    });
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
    _notes = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
