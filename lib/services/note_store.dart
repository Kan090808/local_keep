import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/hive_database_service.dart';

abstract interface class NoteStore {
  Future<List<Note>> fetchNotes();
  Future<String> insertNote(Note note);
  Future<void> updateNote(Note note);
  Future<void> deleteNote(String id);
}

class HiveNoteStore implements NoteStore {
  const HiveNoteStore();

  @override
  Future<List<Note>> fetchNotes() => HiveDatabaseService.getNotes();

  @override
  Future<String> insertNote(Note note) => HiveDatabaseService.insertNote(note);

  @override
  Future<void> updateNote(Note note) => HiveDatabaseService.updateNote(note);

  @override
  Future<void> deleteNote(String id) => HiveDatabaseService.deleteNote(id);
}
