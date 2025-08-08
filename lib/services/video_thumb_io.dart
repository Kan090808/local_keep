import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbService {
  static Future<Uint8List?> fromBytes(Uint8List bytes) async {
    final tmpDir = await getTemporaryDirectory();
    final videoPath =
        '${tmpDir.path}/thumb_${DateTime.now().microsecondsSinceEpoch}.mp4';
    final f = File(videoPath);
    await f.writeAsBytes(bytes, flush: true);
    try {
      final thumbData = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.PNG,
        maxWidth: 512,
        quality: 75,
      );
      return thumbData;
    } finally {
      // ignore: unused_result
      f.delete();
    }
  }
}
