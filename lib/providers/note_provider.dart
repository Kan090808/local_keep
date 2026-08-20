import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_keep/models/media_attachment.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/services/app_logger.dart';
import 'package:local_keep/services/media_service.dart';
import 'package:local_keep/services/note_store.dart';

class NoteProvider with ChangeNotifier {
  NoteProvider({NoteStore? store}) : _store = store ?? const HiveNoteStore();

  final NoteStore _store;
  List<Note> _notes = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  List<Note> get notes => [..._notes];
  bool get isLoading => _isLoading;

  Future<void> fetchNotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notes = await _store.fetchNotes();
    } catch (e) {
      AppLogger.e('Error fetching notes', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNote(
    String content, {
    List<MediaAttachment>? mediaAttachments,
  }) async {
    try {
      final newNote = Note.create(
        content: content,
        mediaAttachments: mediaAttachments,
      );

      final id = await _store.insertNote(newNote);
      final finalNote = newNote.copyWith(id: id);
      _notes.insert(0, finalNote);

      notifyListeners();
    } catch (e) {
      AppLogger.e('Error adding note', e);
      rethrow;
    }
  }

  Future<void> updateNote(
    Note note,
    String content, {
    List<MediaAttachment>? mediaAttachments,
  }) async {
    try {
      final updatedNote = note.copyWith(
        content: content,
        updatedAt: DateTime.now(),
        mediaAttachments: mediaAttachments ?? note.mediaAttachments,
      );

      final noteIndex = _notes.indexWhere((n) => n.id == note.id);
      if (noteIndex >= 0) {
        _notes[noteIndex] = updatedNote;
        notifyListeners();
      }

      await _store.updateNote(updatedNote);
    } catch (e) {
      AppLogger.e('Error updating note', e);
      await fetchNotes();
      rethrow;
    }
  }

  void updateNoteDebounced(
    Note note,
    String content, {
    List<MediaAttachment>? mediaAttachments,
  }) {
    final updatedNote = note.copyWith(
      content: content,
      updatedAt: DateTime.now(),
      mediaAttachments: mediaAttachments ?? note.mediaAttachments,
    );

    final noteIndex = _notes.indexWhere((n) => n.id == note.id);
    if (noteIndex >= 0) {
      _notes[noteIndex] = updatedNote;
      notifyListeners();
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _store.updateNote(updatedNote);
    });
  }

  Future<void> deleteNote(String id) async {
    final note = getNoteById(id);

    if (note != null && note.mediaAttachments.isNotEmpty) {
      for (final media in note.mediaAttachments) {
        await MediaService.deleteMedia(media);
      }
    }

    await _store.deleteNote(id);
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

  /// Drop plaintext notes from memory (called on app lock).
  void clearNotes() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _notes = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
