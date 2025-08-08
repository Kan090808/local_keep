import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:local_keep/models/note_content.dart';

class MediaViewerScreen extends StatelessWidget {
  final NoteContent content;
  const MediaViewerScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(content.dataBase64 ?? '');
    final isImage = content.type == NoteType.image;
    // For simplicity, show images natively; for video/files, offer download/open fallback

    return Scaffold(
      appBar: AppBar(title: Text(content.fileName ?? '')),
      body: Center(
        child:
            isImage
                ? InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                )
                : _buildUnsupported(context),
      ),
    );
  }

  Widget _buildUnsupported(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          content.type == NoteType.video
              ? Icons.videocam
              : Icons.insert_drive_file,
          size: 64,
          color: Colors.grey,
        ),
        const SizedBox(height: 16),
        const Text('Preview not supported. Tap Open to view.'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            // Defer to platform opener
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop('open_external');
          },
          child: const Text('Open'),
        ),
      ],
    );
  }
}
