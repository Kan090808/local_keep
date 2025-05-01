import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/providers/auth_provider.dart';
import 'package:local_keep/providers/note_provider.dart';
import 'package:local_keep/screens/auth_screen.dart';
import 'package:local_keep/screens/note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  bool _isLoading = false;

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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen())
    );
  }

  void _createNote() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NoteEditorScreen(

        )
      )
    ).then((_) => _loadNotes());
  }

  void _editNote(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
        )
      )
    ).then((_) => _loadNotes());
  }

  void _confirmDelete(Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<NoteProvider>(context, listen: false)
                  .deleteNote(note.id!);
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
            icon: const Icon(Icons.lock),
            onPressed: _lockApp,
            tooltip: 'Lock App',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
              ? const Center(
                  child: Text('No notes yet. Tap + to create one.'),
                )
              : Padding(
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
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        tooltip: 'Add Note',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _editNote(note),
        onLongPress: () => _confirmDelete(note),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.content.isNotEmpty)
                Text(
                  note.content,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    note.formattedDate,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDelete(note),
                    color: Colors.red[300],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}