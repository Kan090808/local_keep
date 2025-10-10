import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:local_keep/models/media_attachment.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class MediaService {
  static final _uuid = const Uuid();
  static const String _mediaFolderName = 'encrypted_media';

  /// Get the media storage directory
  static Future<Directory> _getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/$_mediaFolderName');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

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

    // Generate unique ID for this media
    final id = _uuid.v4();
    final mediaDir = await _getMediaDirectory();

    // Encrypt the file data
    final encryptedBytes = await CryptoService.encryptBytes(bytes, password);

    // Save encrypted data to a file in app's internal storage
    final encryptedFilePath = '${mediaDir.path}/$id.enc';
    final encryptedFile = File(encryptedFilePath);
    await encryptedFile.writeAsBytes(base64Decode(encryptedBytes));

    print(
      '✓ Media saved to: $encryptedFilePath (${bytes.length} bytes → ${(await encryptedFile.length())} encrypted bytes)',
    );

    // Generate and save thumbnail for videos
    String? thumbnailPath;
    if (mediaType == MediaType.video) {
      thumbnailPath = await _generateAndSaveVideoThumbnail(
        file.path,
        id,
        password,
      );
    }

    return MediaAttachment(
      id: id,
      fileName: fileName,
      encryptedData: id, // Store ID instead of full encrypted data
      mediaTypeIndex: mediaType.index,
      fileSize: bytes.length,
      mimeType: mimeType,
      createdAt: DateTime.now(),
      thumbnailData: thumbnailPath, // Store thumbnail file ID
    );
  }

  /// Generate and save an encrypted thumbnail for a video
  static Future<String?> _generateAndSaveVideoThumbnail(
    String videoPath,
    String mediaId,
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

      // Encrypt thumbnail
      final encryptedThumbData = await CryptoService.encryptBytes(
        thumbnailBytes,
        password,
      );

      // Save thumbnail to file
      final mediaDir = await _getMediaDirectory();
      final thumbnailId = '${mediaId}_thumb';
      final thumbnailPath = '${mediaDir.path}/$thumbnailId.enc';
      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(base64Decode(encryptedThumbData));

      print('✓ Thumbnail saved to: $thumbnailPath');
      return thumbnailId;
    } catch (e) {
      print('Error generating video thumbnail: $e');
      return null;
    }
  }

  /// Decrypt media data from file
  static Future<Uint8List> decryptMedia(
    MediaAttachment media,
    String password,
  ) async {
    try {
      final mediaDir = await _getMediaDirectory();
      final encryptedFilePath = '${mediaDir.path}/${media.encryptedData}.enc';
      final encryptedFile = File(encryptedFilePath);

      if (!await encryptedFile.exists()) {
        throw Exception('Media file not found: $encryptedFilePath');
      }

      // Read encrypted bytes from file
      final encryptedBytes = await encryptedFile.readAsBytes();

      // Convert to base64 for decryption
      final base64Data = base64Encode(encryptedBytes);

      // Decrypt
      final decryptedBytes = await CryptoService.decryptBytes(
        base64Data,
        password,
      );

      print(
        '✓ Media decrypted: ${media.fileName} (${decryptedBytes.length} bytes)',
      );
      return decryptedBytes;
    } catch (e) {
      print('✗ Error decrypting media: $e');
      rethrow;
    }
  }

  /// Decrypt thumbnail data from file
  static Future<Uint8List?> decryptThumbnail(
    String? thumbnailId,
    String password,
  ) async {
    if (thumbnailId == null) return null;

    try {
      final mediaDir = await _getMediaDirectory();
      final thumbnailPath = '${mediaDir.path}/$thumbnailId.enc';
      final thumbnailFile = File(thumbnailPath);

      if (!await thumbnailFile.exists()) {
        print('⚠ Thumbnail file not found: $thumbnailPath');
        return null;
      }

      // Read and decrypt
      final encryptedBytes = await thumbnailFile.readAsBytes();
      final base64Data = base64Encode(encryptedBytes);
      return await CryptoService.decryptBytes(base64Data, password);
    } catch (e) {
      print('✗ Error decrypting thumbnail: $e');
      return null;
    }
  }

  /// Delete media file
  static Future<void> deleteMedia(MediaAttachment media) async {
    try {
      final mediaDir = await _getMediaDirectory();

      // Delete main media file
      final mediaFile = File('${mediaDir.path}/${media.encryptedData}.enc');
      if (await mediaFile.exists()) {
        await mediaFile.delete();
        print('✓ Deleted media file: ${media.fileName}');
      }

      // Delete thumbnail if exists
      if (media.thumbnailData != null) {
        final thumbFile = File('${mediaDir.path}/${media.thumbnailData}.enc');
        if (await thumbFile.exists()) {
          await thumbFile.delete();
          print('✓ Deleted thumbnail file');
        }
      }
    } catch (e) {
      print('✗ Error deleting media: $e');
    }
  }

  /// Clean up orphaned media files (files not referenced by any note)
  static Future<void> cleanupOrphanedMedia(List<String> referencedIds) async {
    try {
      final mediaDir = await _getMediaDirectory();
      final files = await mediaDir.list().toList();
      int deletedCount = 0;

      for (final file in files) {
        if (file is File && file.path.endsWith('.enc')) {
          final fileName = path.basenameWithoutExtension(file.path);
          final baseId = fileName.replaceAll('_thumb', '');

          if (!referencedIds.contains(baseId)) {
            await file.delete();
            deletedCount++;
            print('✓ Cleaned up orphaned file: ${path.basename(file.path)}');
          }
        }
      }

      if (deletedCount > 0) {
        print('✓ Cleanup complete: $deletedCount orphaned files removed');
      }
    } catch (e) {
      print('✗ Error during cleanup: $e');
    }
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
