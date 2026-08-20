class AutoLockCoordinator {
  bool _isPickingFile = false;
  bool _isPreviewingFile = false;

  bool get isPickingFile => _isPickingFile;
  bool get isPreviewingFile => _isPreviewingFile;
  bool get shouldSkipLock => _isPickingFile || _isPreviewingFile;

  void setPickingFile(bool value) {
    _isPickingFile = value;
  }

  void setPreviewingFile(bool value) {
    _isPreviewingFile = value;
  }
}
