import 'dart:typed_data';

class VideoThumbService {
  static Future<Uint8List?> fromBytes(Uint8List bytes) async {
    // Not supported on web without additional codecs; return null
    return null;
  }
}
