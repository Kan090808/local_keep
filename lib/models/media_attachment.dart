import 'package:hive/hive.dart';

part 'media_attachment.g.dart';

enum MediaType { image, video, file }

@HiveType(typeId: 1)
class MediaAttachment {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fileName;

  @HiveField(2)
  final String encryptedData; // Base64 encoded encrypted bytes

  @HiveField(3)
  final int mediaTypeIndex; // 0: image, 1: video, 2: file

  @HiveField(4)
  final int fileSize; // Original file size in bytes

  @HiveField(5)
  final String? mimeType;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final String? thumbnailData; // Encrypted thumbnail for videos (optional)

  MediaAttachment({
    required this.id,
    required this.fileName,
    required this.encryptedData,
    required this.mediaTypeIndex,
    required this.fileSize,
    this.mimeType,
    required this.createdAt,
    this.thumbnailData,
  });

  MediaType get mediaType => MediaType.values[mediaTypeIndex];

  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'encryptedData': encryptedData,
      'mediaTypeIndex': mediaTypeIndex,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'createdAt': createdAt.toIso8601String(),
      'thumbnailData': thumbnailData,
    };
  }

  factory MediaAttachment.fromMap(Map<String, dynamic> map) {
    return MediaAttachment(
      id: map['id'],
      fileName: map['fileName'],
      encryptedData: map['encryptedData'],
      mediaTypeIndex: map['mediaTypeIndex'],
      fileSize: map['fileSize'],
      mimeType: map['mimeType'],
      createdAt: DateTime.parse(map['createdAt']),
      thumbnailData: map['thumbnailData'],
    );
  }
}
