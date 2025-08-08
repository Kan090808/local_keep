import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_keep/services/video_thumb.dart';
import 'package:flutter/material.dart';
import 'package:local_keep/models/note.dart';
import 'package:local_keep/models/note_content.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onCopy;
  final VoidCallback? onLongPress;
  final int? index;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onCopy,
    this.onLongPress,
    this.index,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return RepaintBoundary(
      child: Card(
        key: ValueKey(widget.note.id),
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMainContent(context),
                          const SizedBox(height: 8),
                          Text(
                            widget.note.formattedDate,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onCopy != null) ...[
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: widget.onCopy,
                            tooltip: 'Copy note',
                            color: Colors.teal,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final parsed = NoteContent.tryParse(widget.note.content);
    if (parsed == null || parsed.type == NoteType.text) {
      final text = parsed?.text ?? widget.note.content;
      if (text.isEmpty) {
        return const Text(
          'Empty Note',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
        );
      }
      return Text(
        text,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16),
      );
    }

    // Media note: show thumb and one-line filename
    final isImage = parsed.type == NoteType.image;
    final isVideo = parsed.type == NoteType.video;
    Uint8List? bytes;
    try {
      bytes = base64Decode(parsed.dataBase64 ?? '');
    } catch (_) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isImage && bytes != null && bytes.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
            ),
          )
        else if (isVideo && !kIsWeb)
          FutureBuilder<Uint8List?>(
            future: _buildVideoThumb(bytes),
            builder: (context, snap) {
              final tb = snap.data;
              if (tb != null && tb.isNotEmpty) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    tb,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                );
              }
              return _placeholderIcon(parsed);
            },
          )
        else
          _placeholderIcon(parsed),
        const SizedBox(height: 8),
        Text(
          parsed.fileName ?? 'file',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _placeholderIcon(NoteContent parsed) {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(
        parsed.type == NoteType.video
            ? Icons.videocam
            : Icons.insert_drive_file,
        color: Colors.grey.shade600,
        size: 32,
      ),
    );
  }

  Future<Uint8List?> _buildVideoThumb(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return await VideoThumbService.fromBytes(bytes);
    } catch (_) {
      return null;
    }
  }
}
