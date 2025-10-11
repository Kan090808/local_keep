import 'dart:async';

/// Service to manage app lifecycle state and prevent auto-lock during file operations
class AppLifecycleService {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  bool _isPickingFile = false;
  bool _isPreviewingFile = false;
  Timer? _previewGracePeriodTimer;

  // Grace period after file preview ends (3 seconds)
  static const Duration _previewGracePeriod = Duration(seconds: 3);

  /// Get whether the app is currently picking a file
  bool get isPickingFile => _isPickingFile;

  /// Get whether the app is currently previewing a file
  bool get isPreviewingFile => _isPreviewingFile;

  /// Get whether the app should skip auto-lock
  /// Returns true if either picking or previewing a file
  bool get shouldSkipLock => _isPickingFile || _isPreviewingFile;

  /// Set the file picking state
  /// Call this before opening file picker to prevent auto-lock
  void setPickingFile(bool value) {
    _isPickingFile = value;
    print('AppLifecycleService: isPickingFile = $_isPickingFile');
  }

  /// Set the file previewing state with optional grace period
  /// Call this before opening file preview to prevent auto-lock
  void setPreviewingFile(bool value, {bool withGracePeriod = false}) {
    // Cancel any existing grace period timer
    _previewGracePeriodTimer?.cancel();
    _previewGracePeriodTimer = null;

    if (!value && withGracePeriod) {
      // When ending preview with grace period, delay the flag reset
      print(
        'AppLifecycleService: Starting preview grace period (${_previewGracePeriod.inSeconds}s)',
      );
      _previewGracePeriodTimer = Timer(_previewGracePeriod, () {
        _isPreviewingFile = false;
        print(
          'AppLifecycleService: isPreviewingFile = $_isPreviewingFile (after grace period)',
        );
      });
    } else {
      // Immediate state change
      _isPreviewingFile = value;
      print('AppLifecycleService: isPreviewingFile = $_isPreviewingFile');
    }
  }

  /// Start file picking operation
  void startFilePicking() {
    setPickingFile(true);
  }

  /// End file picking operation
  void endFilePicking() {
    setPickingFile(false);
  }

  /// Start file previewing operation
  void startFilePreviewing() {
    setPreviewingFile(true);
  }

  /// End file previewing operation with grace period
  /// This prevents immediate lock when returning from system file viewer
  void endFilePreviewing({bool withGracePeriod = true}) {
    setPreviewingFile(false, withGracePeriod: withGracePeriod);
  }

  /// Cancel any ongoing grace period (for cleanup)
  void dispose() {
    _previewGracePeriodTimer?.cancel();
    _previewGracePeriodTimer = null;
  }
}
