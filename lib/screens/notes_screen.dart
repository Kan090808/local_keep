import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/providers/note_provider.dart';
import 'package:local_keep/screens/note_editor_screen.dart';
import 'package:local_keep/screens/settings_screen.dart'; // Import the new settings screen
import 'package:local_keep/widgets/note_card.dart';

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

    // Use post-frame callback to avoid calling provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Provider.of<NoteProvider>(context, listen: false).fetchNotes();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _goToSettings() {
    // New method to navigate to settings
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _createNote() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NoteEditorScreen()))
        .then((result) {
          // The NoteProvider already handles optimistic updates,
          // so we don't need to reload unless there's an error
          if (result == 'error') {
            _loadNotes();
          }
        });
  }

  void _editNote(Note note) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)))
        .then((result) {
          // The NoteProvider already handles optimistic updates,
          // so we don't need to reload unless there's an error
          if (result == 'error') {
            _loadNotes();
          }
        });
  }

  Future<void> _copyNote(Note note) async {
    try {
      await Clipboard.setData(ClipboardData(text: note.content));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note copied to clipboard'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy note: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _enterReorderMode() {
    setState(() {
      _isReorderMode = true;
    });
  }

  void _exitReorderMode() {
    setState(() {
      _isReorderMode = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) async {
    try {
      await Provider.of<NoteProvider>(
        context,
        listen: false,
      ).reorderNotes(oldIndex, newIndex);
    } catch (e) {
      print('Error reordering notes: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reorder notes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        // NoteProvider already handles reverting on error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isReorderMode ? 'Reorder Notes' : 'Local Keep'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          if (_isReorderMode)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _exitReorderMode,
              tooltip: 'Done',
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.reorder),
              onPressed: _enterReorderMode,
              tooltip: 'Reorder Notes',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _goToSettings,
              tooltip: 'Settings',
            ),
          ],
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Selector<NoteProvider, List<Note>>(
                selector: (context, noteProvider) => noteProvider.notes,
                builder: (context, notes, child) {
                  if (notes.isEmpty) {
                    return const Center(
                      child: Text('No notes yet. Tap + to create one.'),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child:
                          _isReorderMode
                              ? _buildReorderView(notes)
                              : _buildListView(notes),
                    ),
                  );
                },
              ),
      floatingActionButton:
          _isReorderMode
              ? null
              : FloatingActionButton(
                onPressed: _createNote,
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                tooltip: 'Add Note',
                child: const Icon(Icons.add),
              ),
    );
  }

  Widget _buildListView(List<Note> notes) {
    return ListView.builder(
      key: const ValueKey('notes_list'),
      itemCount: notes.length,
      cacheExtent: 1000, // Increased cache for better scrolling
      addAutomaticKeepAlives: true, // Keep built widgets alive
      addRepaintBoundaries: true, // Isolate repaints
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildListNoteCard(note, index);
      },
    );
  }

  Widget _buildReorderView(List<Note> notes) {
    return Column(
      children: [
        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.teal, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Drag notes to reorder them. Tap "Done" when finished.',
                  style: TextStyle(color: Colors.teal, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        // Reorderable list
        Expanded(
          child: ReorderableListView(
            onReorder: _onReorder,
            children:
                notes.asMap().entries.map((entry) {
                  return _buildReorderNoteCard(entry.value, entry.key);
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildListNoteCard(Note note, int index) {
    return NoteCard(
      note: note,
      index: index,
      onTap: () => _editNote(note),
      onCopy: () => _copyNote(note),
    );
  }

  Widget _buildReorderNoteCard(Note note, int index) {
    return ReorderableNoteCard(
      note: note,
      index: index,
      onEdit: () => _editNote(note),
    );
  }
}
