import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/providers/auth_provider.dart';
import 'package:local_keep/providers/note_provider.dart';
import 'package:local_keep/screens/auth_screen.dart';
import 'package:local_keep/screens/note_editor_screen.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _isLoading = false;
  bool _isReorderMode = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    await Provider.of<NoteProvider>(context, listen: false).fetchNotes();

    setState(() {
      _isLoading = false;
    });
  }

  void _lockApp() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.lockApp();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _createNote() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NoteEditorScreen()))
        .then((_) => _loadNotes());
  }

  void _editNote(Note note) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)))
        .then((_) => _loadNotes());
  }

  void _confirmDelete(Note note) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Note'),
            content: const Text('Are you sure you want to delete this note?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Provider.of<NoteProvider>(
                    context,
                    listen: false,
                  ).deleteNote(note.id!);
                  Navigator.of(ctx).pop();
                  _loadNotes();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = Provider.of<NoteProvider>(context).notes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Keep'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: Icon(_isReorderMode ? Icons.check : Icons.reorder),
            onPressed: () {
              setState(() {
                _isReorderMode = !_isReorderMode;
              });
            },
            tooltip: _isReorderMode ? 'Done Reordering' : 'Reorder Notes',
          ),
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: _lockApp,
            tooltip: 'Lock App',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : notes.isEmpty
              ? const Center(child: Text('No notes yet. Tap + to create one.'))
              : _isReorderMode
              ? _buildReorderableList(notes)
              : _buildMasonryGrid(notes),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        tooltip: 'Add Note',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMasonryGrid(List<Note> notes) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return _buildNoteCard(note);
        },
      ),
    );
  }

  Widget _buildReorderableList(List<Note> notes) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: notes.length,
      onReorder: (oldIndex, newIndex) {
        Provider.of<NoteProvider>(
          context,
          listen: false,
        ).reorderNotes(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildReorderableNoteCard(note, index);
      },
    );
  }

  Widget _buildReorderableNoteCard(Note note, int index) {
    return Card(
      key: ValueKey(note.id),
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.drag_handle),
        title: Text(
          note.content.isNotEmpty ? note.content : 'Empty note',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          note.formattedDate,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(note),
          color: Colors.red[300],
        ),
        onTap: () => _editNote(note),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.content.isNotEmpty)
              Text(note.content, maxLines: 8, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  note.formattedDate,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: note.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Note copied!')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(note),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save_alt, size: 18),
                      tooltip: 'Save',
                      onPressed: () async {
                        final directory =
                            await getApplicationDocumentsDirectory();
                        final file = File(
                          '${directory.path}/note_${note.id}.txt',
                        );
                        await file.writeAsString(note.content);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Note saved to file!')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
