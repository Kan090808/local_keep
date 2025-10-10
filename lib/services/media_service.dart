import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:local_keep/models/media_attachment.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class MediaService {
  static final _uuid = const Uuid();

  /// Pick images from gallery
  static Future<List<MediaAttachment>?> pickImages(String password) async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (images.isEmpty) return null;

      final attachments = <MediaAttachment>[];
      for (final image in images) {
        final file = File(image.path);
        final attachment = await _createMediaAttachment(
          file,
          MediaType.image,
          password,
        );
        attachments.add(attachment);
      }

      return attachments;
    } catch (e) {
      print('Error picking images: $e');
      return null;
    }
  }

  /// Pick a video from gallery
  static Future<MediaAttachment?> pickVideo(String password) async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);

      if (video == null) return null;

      final file = File(video.path);
      return await _createMediaAttachment(file, MediaType.video, password);
    } catch (e) {
      print('Error picking video: $e');
      return null;
    }
  }

  /// Pick files
  static Future<List<MediaAttachment>?> pickFiles(String password) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return null;

      final attachments = <MediaAttachment>[];
      for (final fileInfo in result.files) {
        if (fileInfo.path != null) {
          final file = File(fileInfo.path!);
          final attachment = await _createMediaAttachment(
            file,
            MediaType.file,
            password,
          );
          attachments.add(attachment);
        }
      }

      return attachments;
    } catch (e) {
      print('Error picking files: $e');
      return null;
    }
  }

  /// Create a media attachment from a file
  static Future<MediaAttachment> _createMediaAttachment(
    File file,
    MediaType mediaType,
    String password,
  ) async {
    final bytes = await file.readAsBytes();
    final fileName = path.basename(file.path);
    final mimeType = lookupMimeType(file.path);

    // Encrypt the file data
    final encryptedData = await CryptoService.encryptBytes(bytes, password);

    // Generate thumbnail for videos
    String? thumbnailData;
    if (mediaType == MediaType.video) {
      thumbnailData = await _generateVideoThumbnail(file.path, password);
    }

    return MediaAttachment(
      id: _uuid.v4(),
      fileName: fileName,
      encryptedData: encryptedData,
      mediaTypeIndex: mediaType.index,
      fileSize: bytes.length,
      mimeType: mimeType,
      createdAt: DateTime.now(),
      thumbnailData: thumbnailData,
    );
  }

  /// Generate an encrypted thumbnail for a video
  static Future<String?> _generateVideoThumbnail(
    String videoPath,
    String password,
  ) async {
    try {
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 75,
      );

      if (thumbnailBytes == null) return null;

      return await CryptoService.encryptBytes(thumbnailBytes, password);
    } catch (e) {
      print('Error generating video thumbnail: $e');
      return null;
    }
  }

  /// Decrypt media data
  static Future<Uint8List> decryptMedia(
    MediaAttachment media,
    String password,
  ) async {
    return await CryptoService.decryptBytes(media.encryptedData, password);
  }

  /// Decrypt thumbnail data
  static Future<Uint8List?> decryptThumbnail(
    String? thumbnailData,
    String password,
  ) async {
    if (thumbnailData == null) return null;
    return await CryptoService.decryptBytes(thumbnailData, password);
  }

  /// Get icon for file type
  static String getFileIcon(String? mimeType) {
    if (mimeType == null) return '📄';

    if (mimeType.startsWith('image/')) return '🖼️';
    if (mimeType.startsWith('video/')) return '🎥';
    if (mimeType.startsWith('audio/')) return '🎵';
    if (mimeType.contains('pdf')) return '📕';
    if (mimeType.contains('word') || mimeType.contains('document')) return '📘';
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet'))
      return '📊';
    if (mimeType.contains('powerpoint') || mimeType.contains('presentation'))
      return '📙';
    if (mimeType.contains('zip') || mimeType.contains('compressed'))
      return '📦';
    if (mimeType.contains('text')) return '📝';

    return '📄';
  }
}
