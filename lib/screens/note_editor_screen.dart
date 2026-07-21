import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/models/media_attachment.dart';
import 'package:local_keep/providers/note_provider.dart';
import 'package:local_keep/services/hive_database_service.dart';
import 'package:local_keep/services/media_service.dart';
import 'package:local_keep/widgets/media_gallery_widget.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _contentController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isEdited = false;
  bool _isSaving = false;
  String _lastSavedContent = '';
  Timer? _saveTimer;
  List<MediaAttachment> _mediaAttachments = [];

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _contentController.text = widget.note!.content;
      _lastSavedContent = widget.note!.content;
      _mediaAttachments = List.from(widget.note!.mediaAttachments);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_focusNode);
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _focusNode.dispose();
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_isSaving) return; // Prevent multiple simultaneous saves

    final content = _contentController.text.trim();

    // Don't save completely empty notes (no content and no media)
    if (content.isEmpty && _mediaAttachments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot save empty note'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final noteProvider = Provider.of<NoteProvider>(context, listen: false);

    try {
      if (widget.note == null) {
        // Create new note
        await noteProvider.addNote(
          content,
          mediaAttachments: _mediaAttachments,
        );
      } else {
        // Update existing note
        await noteProvider.updateNote(
          widget.note!,
          content,
          mediaAttachments: _mediaAttachments,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Note saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        setState(() {
          _isEdited = false;
          _isSaving = false;
        });
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _addImages() async {
    final password = HiveDatabaseService.getPassword();

    if (password == null) return;

    final images = await MediaService.pickImages(password);
    if (images != null && images.isNotEmpty) {
      setState(() {
        _mediaAttachments.addAll(images);
        _isEdited = true;
      });
    }
  }

  Future<void> _addVideo() async {
    final password = HiveDatabaseService.getPassword();
    if (password == null) return;

    final video = await MediaService.pickVideo(password);
    if (video != null) {
      setState(() {
        _mediaAttachments.add(video);
        _isEdited = true;
      });
    }
  }

  Future<void> _addFiles() async {
    final password = HiveDatabaseService.getPassword();
    if (password == null) return;

    final files = await MediaService.pickFiles(password);
    if (files != null && files.isNotEmpty) {
      setState(() {
        _mediaAttachments.addAll(files);
        _isEdited = true;
      });
    }
  }

  void _deleteMedia(MediaAttachment media) {
    setState(() {
      _mediaAttachments.remove(media);
      _isEdited = true;
    });
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Add Images'),
                  onTap: () {
                    Navigator.pop(context);
                    _addImages();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam),
                  title: const Text('Add Video'),
                  onTap: () {
                    Navigator.pop(context);
                    _addVideo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: const Text('Add Files'),
                  onTap: () {
                    Navigator.pop(context);
                    _addFiles();
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _copyNote() {
    final content = _contentController.text;
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note content copied to clipboard')),
    );
  }

  void _deleteNote() {
    if (widget.note != null) {
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
                    ).deleteNote(widget.note!.id!);
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop(); // Close editor screen
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isEdited && !_isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Prevent popping if currently saving
        if (_isSaving) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot go back while saving...'),
              duration: Duration(seconds: 1),
            ),
          );
          return;
        }

        // Show confirmation if there are unsaved edits
        final shouldPop =
            await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Discard changes?'),
                    content: const Text(
                      'You have unsaved changes. Do you want to discard them?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Keep editing'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Discard'),
                      ),
                    ],
                  ),
            ) ??
            false;

        if (shouldPop && context.mounted) {
          Navigator.of(context).pop(_isEdited ? true : false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: 'Add Media',
              onPressed: _isSaving ? null : _showMediaOptions,
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy',
              onPressed: _isSaving ? null : _copyNote,
            ),
            if (widget.note != null) ...[
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete',
                onPressed: _isSaving ? null : _deleteNote,
              ),
            ],
            IconButton(
              icon:
                  _isSaving
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _isSaving ? null : _saveNote,
            ),
          ],
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.note != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Edited: ${widget.note!.formattedDate}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _contentController,
                            focusNode: _focusNode,
                            enabled: !_isSaving,
                            decoration: const InputDecoration(
                              hintText: 'Note content',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(fontSize: 16),
                            maxLines: null,
                            minLines: 5,
                            keyboardType: TextInputType.multiline,
                            onChanged: (value) {
                              final contentLength = value.length;
                              final lastSavedLength = _lastSavedContent.length;
                              final hasSignificantChange =
                                  (lastSavedLength - contentLength).abs() > 3;
                              final crossedWordBoundary =
                                  (contentLength ~/ 20) !=
                                  (lastSavedLength ~/ 20);

                              if (!_isEdited && (value != _lastSavedContent)) {
                                setState(() => _isEdited = true);
                              }

                              if (widget.note != null &&
                                  (hasSignificantChange ||
                                      crossedWordBoundary)) {
                                final noteProvider = Provider.of<NoteProvider>(
                                  context,
                                  listen: false,
                                );
                                noteProvider.updateNoteDebounced(
                                  widget.note!,
                                  value,
                                  mediaAttachments: _mediaAttachments,
                                );
                                _lastSavedContent = value;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_mediaAttachments.isNotEmpty) ...[
                            MediaGalleryWidget(
                              mediaAttachments: _mediaAttachments,
                              password: HiveDatabaseService.getPassword() ?? '',
                              onDeleteMedia: _deleteMedia,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Loading overlay during save
            if (_isSaving)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    // Prevent dismissal
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
