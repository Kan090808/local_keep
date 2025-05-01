import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Import the intl package
import 'package:local_keep/models/note.dart';
import 'package:local_keep/providers/note_provider.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({
    super.key,
    this.note,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _contentController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isEdited = false;

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _contentController.text = widget.note!.content;
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
    super.dispose();
  }

  Future<void> _saveNote() async {
    final content = _contentController.text.trim();
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);

    if (widget.note == null) {
      // Create new note
      await noteProvider.addNote(content);
    } else {
      // Update existing note
      await noteProvider.updateNote(widget.note!, content);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isEdited,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('You have unsaved changes. Do you want to discard them?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ?? false;
        
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveNote,
              tooltip: 'Save',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align date to the start
            children: [
              if (widget.note != null) // Only show date for existing notes
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Edited: ${widget.note!.formattedDate}', // Format and display the date
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
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
                  onChanged: (value) => setState(() => _isEdited = true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}