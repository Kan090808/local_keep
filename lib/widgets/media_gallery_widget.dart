import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:local_keep/models/media_attachment.dart';
import 'package:local_keep/services/media_service.dart';
import 'package:local_keep/widgets/media_viewer.dart';

class MediaGalleryWidget extends StatelessWidget {
  final List<MediaAttachment> mediaAttachments;
  final String password;
  final VoidCallback? onAddMedia;
  final Function(MediaAttachment)? onDeleteMedia;

  const MediaGalleryWidget({
    super.key,
    required this.mediaAttachments,
    required this.password,
    this.onAddMedia,
    this.onDeleteMedia,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaAttachments.isEmpty) {
      return const SizedBox.shrink();
    }

    // Separate media by type
    final images =
        mediaAttachments.where((m) => m.mediaType == MediaType.image).toList();
    final videos =
        mediaAttachments.where((m) => m.mediaType == MediaType.video).toList();
    final files =
        mediaAttachments.where((m) => m.mediaType == MediaType.file).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Images Grid
        if (images.isNotEmpty) ...[
          _buildImageGrid(context, images),
          const SizedBox(height: 12),
        ],

        // Videos
        if (videos.isNotEmpty) ...[
          _buildVideosList(context, videos),
          const SizedBox(height: 12),
        ],

        // Files
        if (files.isNotEmpty) ...[_buildFilesList(context, files)],
      ],
    );
  }

  Widget _buildImageGrid(BuildContext context, List<MediaAttachment> images) {
    final columns = images.length == 1 ? 1 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return _MediaImageTile(
          media: image,
          password: password,
          onTap: () => _openMediaViewer(context, images, index),
          onDelete: onDeleteMedia != null ? () => onDeleteMedia!(image) : null,
        );
      },
    );
  }

  Widget _buildVideosList(BuildContext context, List<MediaAttachment> videos) {
    return Column(
      children:
          videos.map((video) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _MediaVideoTile(
                media: video,
                password: password,
                onTap:
                    () => _openMediaViewer(
                      context,
                      videos,
                      videos.indexOf(video),
                    ),
                onDelete:
                    onDeleteMedia != null ? () => onDeleteMedia!(video) : null,
              ),
            );
          }).toList(),
    );
  }

  Widget _buildFilesList(BuildContext context, List<MediaAttachment> files) {
    return Column(
      children:
          files.map((file) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _MediaFileTile(
                media: file,
                password: password,
                onDelete:
                    onDeleteMedia != null ? () => onDeleteMedia!(file) : null,
              ),
            );
          }).toList(),
    );
  }

  void _openMediaViewer(
    BuildContext context,
    List<MediaAttachment> mediaList,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => MediaViewer(
              mediaList: mediaList,
              initialIndex: initialIndex,
              password: password,
            ),
      ),
    );
  }
}

// Image Tile Widget
class _MediaImageTile extends StatefulWidget {
  final MediaAttachment media;
  final String password;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _MediaImageTile({
    required this.media,
    required this.password,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_MediaImageTile> createState() => _MediaImageTileState();
}

class _MediaImageTileState extends State<_MediaImageTile> {
  Uint8List? _imageBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await MediaService.decryptMedia(
        widget.media,
        widget.password,
      );
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                _isLoading
                    ? Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    )
                    : _imageBytes != null
                    ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                    : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.error),
                    ),
          ),
          if (widget.onDelete != null)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                onPressed: widget.onDelete,
              ),
            ),
        ],
      ),
    );
  }
}

// Video Tile Widget
class _MediaVideoTile extends StatefulWidget {
  final MediaAttachment media;
  final String password;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _MediaVideoTile({
    required this.media,
    required this.password,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_MediaVideoTile> createState() => _MediaVideoTileState();
}

class _MediaVideoTileState extends State<_MediaVideoTile> {
  Uint8List? _thumbnailBytes;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final bytes = await MediaService.decryptThumbnail(
        widget.media.thumbnailData,
        widget.password,
      );
      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            if (_thumbnailBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _thumbnailBytes!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.media.fileName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            if (widget.onDelete != null)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: widget.onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// File Tile Widget
class _MediaFileTile extends StatelessWidget {
  final MediaAttachment media;
  final String password;
  final VoidCallback? onDelete;

  const _MediaFileTile({
    required this.media,
    required this.password,
    this.onDelete,
  });

  Future<void> _openFile(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await MediaService.openFileWithNativePreview(
        media,
        password,
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('無法開啟此檔案'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('開啟檔案時發生錯誤: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openFile(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Text(
              MediaService.getFileIcon(media.mimeType),
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    media.formattedSize,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
