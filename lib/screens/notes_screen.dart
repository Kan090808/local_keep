import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
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

  Future<void> _createNote() async {
    final type = await showModalBottomSheet<NoteType>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Text'),
              onTap: () => Navigator.pop(context, NoteType.text),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () => Navigator.pop(context, NoteType.image),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, NoteType.video),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('File'),
              onTap: () => Navigator.pop(context, NoteType.file),
            ),
          ],
        ),
      ),
    );

    if (type == null) return;

    if (type == NoteType.text) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const NoteEditorScreen()))
          .then((result) {
        if (result == 'error') {
          _loadNotes();
        }
      });
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: type == NoteType.image
            ? FileType.image
            : type == NoteType.video
                ? FileType.video
                : FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        await Provider.of<NoteProvider>(context, listen: false)
            .addNote(result.files.single.path!, type: type);
      }
    }
  }

  void _editNote(Note note) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)))
        .then((result) {
          if (result == 'error') {
            _loadNotes();
          }
        });
  }

  Future<void> _onNoteTap(Note note) async {
    if (note.type == NoteType.text) {
      _editNote(note);
    } else {
      await OpenFilex.open(note.content);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Keep'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _goToSettings,
            tooltip: 'Settings',
          ),
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
                    child: _buildListView(notes),
                  );
                },
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

  Widget _buildListNoteCard(Note note, int index) {
    return NoteCard(
      note: note,
      index: index,
      onTap: () => _onNoteTap(note),
      onCopy: note.type == NoteType.text ? () => _copyNote(note) : null,
    );
  }
}
