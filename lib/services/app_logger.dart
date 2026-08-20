import 'package:flutter/foundation.dart';

/// Release-safe logger: only emits in debug/profile builds.
class AppLogger {
  static void d(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void e(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint(error == null ? message : '$message: $error');
    }
  }
}
