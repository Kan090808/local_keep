import 'package:local_keep/models/note.dart';

class NoteObjectPool {
  static final List<Note> _pool = [];
  static const int maxPoolSize = 50; // Limit pool size to prevent memory leaks

  // Get a note object from the pool or create a new one
  static Note getNote({
    String? id,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
    int orderIndex = 0,
  }) {
    // Always create new objects since Note is immutable
    // The pool is more useful for managing large collections
    return Note(
      id: id,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      orderIndex: orderIndex,
    );
  }

  // Return a note object to the pool
  static void returnNote(Note note) {
    if (_pool.length < maxPoolSize) {
      _pool.add(note);
    }
    // If pool is full, let the note be garbage collected
  }

  // Return multiple notes to the pool
  static void returnNotes(List<Note> notes) {
    for (final note in notes) {
      returnNote(note);
    }
  }

  // Clear the pool (useful for memory cleanup)
  static void clearPool() {
    _pool.clear();
  }

  // Get pool statistics
  static int get poolSize => _pool.length;
  static int get maxSize => maxPoolSize;
}
