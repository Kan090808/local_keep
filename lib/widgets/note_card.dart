import 'package:flutter/material.dart';
import 'package:local_keep/models/note.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onCopy;
  final int? index;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onCopy,
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
                          if (widget.note.content.isNotEmpty)
                            Text(
                              widget.note.content,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16),
                            )
                          else
                            const Text(
                              'Empty Note',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                              ),
                            ),
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
}
