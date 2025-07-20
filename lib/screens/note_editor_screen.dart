import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/providers/note_provider.dart';

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
  String _lastSavedContent = '';
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _contentController.text = widget.note!.content;
      _lastSavedContent = widget.note!.content;
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
    final content = _contentController.text.trim();
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);

    try {
      if (widget.note == null) {
        // Create new note
        await noteProvider.addNote(content);
      } else {
        // Update existing note
        await noteProvider.updateNote(widget.note!, content);
      }

      if (mounted) {
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate changes were made
      }
    } catch (e) {
      print('Error saving note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save note: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      canPop: !_isEdited,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
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
              icon: const Icon(Icons.copy),
              tooltip: 'Copy',
              onPressed: _copyNote,
            ),
            if (widget.note != null)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete',
                onPressed: _deleteNote,
              ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _saveNote,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align date to the start
            children: [
              if (widget.note != null) // Only show date for existing notes
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Edited: ${widget.note!.formattedDate}', // Format and display the date
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(
                    hintText: 'Note content',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 16),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  onChanged: (value) {
                    // Enhanced change detection for better performance
                    final contentLength = value.length;
                    final lastSavedLength = _lastSavedContent.length;
                    final hasSignificantChange = (lastSavedLength - contentLength).abs() > 3;
                    final crossedWordBoundary = (contentLength ~/ 20) != (lastSavedLength ~/ 20);
                    
                    // More intelligent edit state management
                    if (!_isEdited && (value != _lastSavedContent)) {
                      setState(() => _isEdited = true);
                    }

                    // Auto-save existing notes with smart debouncing
                    if (widget.note != null && (hasSignificantChange || crossedWordBoundary)) {
                      final noteProvider = Provider.of<NoteProvider>(
                        context,
                        listen: false,
                      );
                      noteProvider.updateNoteDebounced(widget.note!, value);
                      _lastSavedContent = value; // Update after debounced call
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
