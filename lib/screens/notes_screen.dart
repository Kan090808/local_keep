import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/providers/note_provider.dart';
import 'package:local_keep/screens/note_editor_screen.dart';
import 'package:local_keep/screens/settings_screen.dart'; // Import the new settings screen
import 'package:local_keep/widgets/note_card.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_keep/services/file_opener.dart';
import 'package:local_keep/screens/media_viewer_screen.dart';
import 'package:local_keep/models/note_content.dart';

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

  void _createNote() {
    _showAddMenu();
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
      final parsed = NoteContent.tryParse(note.content);
      final text =
          parsed == null || parsed.type == NoteType.text
              ? (parsed?.text ?? note.content)
              : null;
      if (text == null || text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nothing to copy.')));
        return;
      }
      await Clipboard.setData(ClipboardData(text: text));
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
    final parsed = NoteContent.tryParse(note.content);
    return NoteCard(
      note: note,
      index: index,
      onTap: () => _handleOpenNote(note),
      onCopy:
          (parsed == null || parsed.type == NoteType.text)
              ? () => _copyNote(note)
              : null,
      onLongPress: () => _handleNoteLongPress(note),
    );
  }

  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Text note'),
                onTap: () => Navigator.pop(ctx, 'text'),
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image'),
                onTap: () => Navigator.pop(ctx, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Video'),
                onTap: () => Navigator.pop(ctx, 'video'),
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('File'),
                onTap: () => Navigator.pop(ctx, 'file'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    switch (choice) {
      case 'text':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const NoteEditorScreen()))
            .then((result) {
              if (result == 'error') {
                _loadNotes();
              }
            });
        break;
      case 'image':
        _pickAndSaveMedia(
          NoteType.image,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        );
        break;
      case 'video':
        _pickAndSaveMedia(
          NoteType.video,
          allowedExtensions: ['mp4', 'mov', 'webm', 'mkv'],
        );
        break;
      case 'file':
        _pickAndSaveMedia(NoteType.file);
        break;
      default:
        break;
    }
  }

  Future<void> _pickAndSaveMedia(
    NoteType type, {
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions == null ? FileType.any : FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final initialName = file.name;
      final renamed = await _promptRename(initialName);
      if (renamed == null) return;

      if (file.bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cannot read file data.')));
        return;
      }
      // Show loading while processing
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final dataBase64 = base64Encode(file.bytes!);
      final mime =
          file.extension != null
              ? _guessMimeFromExtension(initialName)
              : 'application/octet-stream';

      final content = NoteContent.media(
        type: type,
        fileName: renamed,
        mimeType: mime,
        dataBase64: dataBase64,
      );

      await Provider.of<NoteProvider>(
        context,
        listen: false,
      ).addNote(content.encode());
      if (mounted)
        Navigator.of(context, rootNavigator: true).pop(); // close loading
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Media note added.')));
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    }
  }

  Future<String?> _promptRename(String initial) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'File name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _guessMimeFromExtension(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'application/octet-stream';
  }

  Future<void> _handleOpenNote(Note note) async {
    final parsed = NoteContent.tryParse(note.content);
    if (parsed == null || parsed.type == NoteType.text) {
      _editNote(note);
      return;
    }

    try {
      // Open in-app viewer first
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MediaViewerScreen(content: parsed)),
      );
      if (result == 'open_external') {
        await FileOpener.openBase64(
          fileName: parsed.fileName ?? 'file',
          dataBase64: parsed.dataBase64 ?? '',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot open file: $e')));
    }
  }

  Future<void> _handleNoteLongPress(Note note) async {
    final parsed = NoteContent.tryParse(note.content);
    final isMedia = parsed != null && parsed.type != NoteType.text;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMedia)
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Rename'),
                    onTap: () => Navigator.pop(ctx, 'rename'),
                  ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete'),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(ctx, 'cancel'),
                ),
              ],
            ),
          ),
    );

    if (!mounted || action == null || action == 'cancel') return;
    if (action == 'delete') {
      await Provider.of<NoteProvider>(
        context,
        listen: false,
      ).deleteNote(note.id!);
      return;
    }

    if (action == 'rename' && isMedia) {
      final newName = await _promptRename(parsed.fileName ?? 'file');
      if (newName == null || newName.isEmpty) return;
      final updated = NoteContent.media(
        type: parsed.type,
        fileName: newName,
        mimeType: parsed.mimeType ?? 'application/octet-stream',
        dataBase64: parsed.dataBase64 ?? '',
      );
      await Provider.of<NoteProvider>(
        context,
        listen: false,
      ).updateNote(note, updated.encode());
    }
  }
}
