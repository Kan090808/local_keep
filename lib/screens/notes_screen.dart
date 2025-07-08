import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/providers/note_provider.dart';
import 'package:local_keep/screens/note_editor_screen.dart';
import 'package:local_keep/screens/settings_screen.dart'; // Import the new settings screen

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


  void _goToSettings() { // New method to navigate to settings
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
      await Provider.of<NoteProvider>(context, listen: false)
          .reorderNotes(oldIndex, newIndex);
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
        // Reload notes to revert UI changes
        _loadNotes();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = Provider.of<NoteProvider>(context).notes;
    
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
              ? const Center(
                  child: Text('No notes yet. Tap + to create one.'),
                )
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isReorderMode
                        ? _buildReorderView(notes)
                        : _buildGridView(notes),
                  ),
                ),
      floatingActionButton: _isReorderMode
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

  Widget _buildGridView(List<Note> notes) {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildGridNoteCard(note, index);
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
            children: notes.asMap().entries.map((entry) {
              return _buildReorderNoteCard(entry.value, entry.key);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildGridNoteCard(Note note, int index) {
    return Card(
      key: ValueKey(note.id),
      elevation: 2,
      child: InkWell(
        onTap: () => _editNote(note),
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
                )
              else
                const Text(
                  'Empty Note',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReorderNoteCard(Note note, int index) {
    return Card(
      key: ValueKey(note.id),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.drag_handle, color: Colors.grey),
        title: Text(
          note.content.isNotEmpty ? note.content : 'Empty Note',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: note.content.isNotEmpty ? null : Colors.grey,
            fontStyle: note.content.isNotEmpty ? null : FontStyle.italic,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editNote(note),
          tooltip: 'Edit Note',
        ),
      ),
    );
  }
}