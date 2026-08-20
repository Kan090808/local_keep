import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:local_keep/models/media_attachment.dart';
import 'package:local_keep/services/app_lifecycle_service.dart';
import 'package:local_keep/services/app_logger.dart';
import 'package:local_keep/services/crypto_service.dart';
import 'package:local_keep/services/encrypted_media_store.dart';
import 'package:local_keep/services/file_preview_service.dart';

class MediaService {
  static final _uuid = const Uuid();
  static final _mediaStore = EncryptedMediaStore();
  static const _previewSubdir = 'secure_preview';

  static Future<Directory> _getMediaDirectory() async {
    return _mediaStore.directory();
  }

  static Future<Uint8List?> readEncryptedMediaFile(String fileId) async {
    return _mediaStore.read(fileId);
  }

  static Future<void> writeEncryptedMediaFile(
    String fileId,
    Uint8List data,
  ) async {
    await _mediaStore.write(fileId, data);
  }

  static Future<void> clearAllMedia() async {
    await _mediaStore.clear();
  }

  static Future<Map<String, Uint8List>> snapshotEncryptedMedia() {
    return _mediaStore.snapshot();
  }

  static Future<void> replaceAllEncryptedMedia(Map<String, Uint8List> files) {
    return _mediaStore.replaceAll(files);
  }

  static Future<Directory> _previewDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/$_previewSubdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Remove any decrypted preview files from the secure preview cache.
  static Future<void> cleanupPreviewTempFiles() async {
    try {
      final dir = await _previewDirectory();
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          await entity.delete();
        }
      }
    } catch (e) {
      AppLogger.e('Failed to cleanup preview temps', e);
    }
  }

  static Future<List<MediaAttachment>?> pickImages(String password) async {
    final lifecycleService = AppLifecycleService();
    try {
      lifecycleService.startFilePicking();

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
      AppLogger.e('Error picking images', e);
      return null;
    } finally {
      lifecycleService.endFilePicking();
    }
  }

  static Future<MediaAttachment?> pickVideo(String password) async {
    final lifecycleService = AppLifecycleService();
    try {
      lifecycleService.startFilePicking();

      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);

      if (video == null) return null;

      final file = File(video.path);
      return await _createMediaAttachment(file, MediaType.video, password);
    } catch (e) {
      AppLogger.e('Error picking video', e);
      return null;
    } finally {
      lifecycleService.endFilePicking();
    }
  }

  static Future<List<MediaAttachment>?> pickFiles(String password) async {
    final lifecycleService = AppLifecycleService();
    try {
      lifecycleService.startFilePicking();

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
      AppLogger.e('Error picking files', e);
      return null;
    } finally {
      lifecycleService.endFilePicking();
    }
  }

  static Future<MediaAttachment> _createMediaAttachment(
    File file,
    MediaType mediaType,
    String password,
  ) async {
    final bytes = await file.readAsBytes();
    final fileName = path.basename(file.path);
    final mimeType = lookupMimeType(file.path);

    final id = _uuid.v4();
    final encryptedBytes = await CryptoService.encryptBytes(bytes, password);

    await _mediaStore.write(id, base64Decode(encryptedBytes));

    AppLogger.d('Media saved id=$id size=${bytes.length}');

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
      encryptedData: id,
      mediaTypeIndex: mediaType.index,
      fileSize: bytes.length,
      mimeType: mimeType,
      createdAt: DateTime.now(),
      thumbnailData: thumbnailPath,
    );
  }

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

      final encryptedThumbData = await CryptoService.encryptBytes(
        thumbnailBytes,
        password,
      );

      final thumbnailId = '${mediaId}_thumb';
      await _mediaStore.write(thumbnailId, base64Decode(encryptedThumbData));
      return thumbnailId;
    } catch (e) {
      AppLogger.e('Error generating video thumbnail', e);
      return null;
    }
  }

  static Future<Uint8List> decryptMedia(
    MediaAttachment media,
    String password,
  ) async {
    try {
      final decryptedBytes = await _mediaStore.readDecrypted(
        media.encryptedData,
        password,
      );
      return decryptedBytes;
    } catch (e) {
      AppLogger.e('Error decrypting media', e);
      rethrow;
    }
  }

  static Future<Uint8List?> decryptThumbnail(
    String? thumbnailId,
    String password,
  ) async {
    if (thumbnailId == null) return null;

    try {
      return await _mediaStore.readDecryptedThumbnail(thumbnailId, password);
    } catch (e) {
      AppLogger.e('Error decrypting thumbnail', e);
      return null;
    }
  }

  static Future<void> deleteMedia(MediaAttachment media) async {
    try {
      await _mediaStore.delete(media);
    } catch (e) {
      AppLogger.e('Error deleting media', e);
    }
  }

  static Future<void> cleanupOrphanedMedia(List<String> referencedIds) async {
    try {
      final mediaDir = await _getMediaDirectory();
      final files = await mediaDir.list().toList();
      var deletedCount = 0;

      for (final file in files) {
        if (file is File && file.path.endsWith('.enc')) {
          final fileName = path.basenameWithoutExtension(file.path);
          final baseId = fileName.replaceAll('_thumb', '');

          if (!referencedIds.contains(baseId)) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        AppLogger.d('Cleanup removed $deletedCount orphaned media files');
      }
    } catch (e) {
      AppLogger.e('Error during media cleanup', e);
    }
  }

  static String getFileIcon(String? mimeType) {
    if (mimeType == null) return '📄';
    if (mimeType.startsWith('image/')) return '🖼️';
    if (mimeType.startsWith('video/')) return '🎥';
    if (mimeType.startsWith('audio/')) return '🎵';
    if (mimeType.contains('pdf')) return '📕';
    if (mimeType.contains('word') || mimeType.contains('document')) return '📘';
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return '📊';
    }
    if (mimeType.contains('powerpoint') || mimeType.contains('presentation')) {
      return '📙';
    }
    if (mimeType.contains('zip') || mimeType.contains('compressed')) {
      return '📦';
    }
    if (mimeType.contains('text')) return '📝';
    return '📄';
  }

  /// Decrypt to a random-named temp file under a dedicated preview dir, open
  /// native viewer, then schedule cleanup. External apps may still copy data
  /// while the URI is granted — treat as intentional disclosure.
  static Future<bool> openFileWithNativePreview(
    MediaAttachment media,
    String password,
  ) async {
    final lifecycleService = AppLifecycleService();
    File? tempFile;
    try {
      lifecycleService.startFilePreviewing();

      if (!FilePreviewService.isAvailable) {
        return false;
      }

      final decryptedBytes = await decryptMedia(media, password);
      final previewDir = await _previewDirectory();

      final safeExt = path.extension(media.fileName);
      final randomName = '${_uuid.v4()}$safeExt';
      final tempFilePath = '${previewDir.path}/$randomName';

      tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(decryptedBytes, flush: true);

      final success = await FilePreviewService.previewFile(tempFilePath);
      return success;
    } catch (e) {
      AppLogger.e('Error opening file with native preview', e);
      return false;
    } finally {
      // Best-effort delete after handoff; OS may still hold the FD briefly.
      try {
        if (tempFile != null && await tempFile.exists()) {
          // Delay slightly so the viewer can open the file first.
          Future<void>.delayed(const Duration(seconds: 30), () async {
            try {
              if (await tempFile!.exists()) {
                await tempFile.delete();
              }
            } catch (_) {}
          });
        }
      } catch (_) {}
      lifecycleService.endFilePreviewing();
    }
  }
}
