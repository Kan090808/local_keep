/// Service to manage app lifecycle state and prevent auto-lock during file picking
class AppLifecycleService {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  bool _isPickingFile = false;

  /// Get whether the app is currently picking a file
  bool get isPickingFile => _isPickingFile;

  /// Set the file picking state
  /// Call this before opening file picker to prevent auto-lock
  void setPickingFile(bool value) {
    _isPickingFile = value;
    print('AppLifecycleService: isPickingFile = $_isPickingFile');
  }

  /// Start file picking operation
  void startFilePicking() {
    setPickingFile(true);
  }

  /// End file picking operation
  void endFilePicking() {
    setPickingFile(false);
  }
}
