import 'dart:io';
import 'package:flutter/services.dart';

/// Service for previewing files using native platform viewers
class FilePreviewService {
  static const MethodChannel _channel = MethodChannel(
    'com.local_keep/file_preview',
  );

  /// Preview a file using the native iOS UIDocumentInteractionController
  /// or Android Intent on respective platforms
  static Future<bool> previewFile(String filePath) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      print('File preview is only supported on iOS and Android');
      return false;
    }

    try {
      final result = await _channel.invokeMethod('previewFile', {
        'filePath': filePath,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('Error previewing file: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('Unexpected error previewing file: $e');
      return false;
    }
  }

  /// Check if file preview is available on current platform
  static bool get isAvailable {
    return Platform.isIOS || Platform.isAndroid;
  }
}
