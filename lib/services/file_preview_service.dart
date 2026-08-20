import 'dart:io';

import 'package:flutter/services.dart';
import 'package:local_keep/services/app_logger.dart';

/// Service for previewing files using native platform viewers.
class FilePreviewService {
  static const MethodChannel _channel = MethodChannel(
    'com.local_keep/file_preview',
  );

  static Future<bool> previewFile(String filePath) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      AppLogger.d('File preview only supported on iOS/Android');
      return false;
    }

    try {
      final result = await _channel.invokeMethod('previewFile', {
        'filePath': filePath,
      });
      return result == true;
    } on PlatformException catch (e) {
      AppLogger.e('Error previewing file: ${e.code}', e.message);
      return false;
    } catch (e) {
      AppLogger.e('Unexpected error previewing file', e);
      return false;
    }
  }

  static bool get isAvailable => Platform.isIOS || Platform.isAndroid;
}
