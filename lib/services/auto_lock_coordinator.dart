class AutoLockCoordinator {
  int _activeOperations = 0;
  bool _isPickingFile = false;
  bool _isPreviewingFile = false;

  bool get isPickingFile => _isPickingFile;
  bool get isPreviewingFile => _isPreviewingFile;
  bool get shouldSkipLock =>
      _activeOperations > 0 || _isPickingFile || _isPreviewingFile;

  void setPickingFile(bool value) {
    _isPickingFile = value;
  }

  void setPreviewingFile(bool value) {
    _isPreviewingFile = value;
  }

  void Function() beginOperation() {
    _activeOperations++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (_activeOperations > 0) _activeOperations--;
    };
  }
}
