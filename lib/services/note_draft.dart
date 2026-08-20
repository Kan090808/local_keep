class NoteDraft {
  NoteDraft(String content) : _savedContent = content, _content = content;

  String _savedContent;
  String _content;

  String get content => _content;
  bool get isDirty => _content != _savedContent;

  void updateContent(String content) {
    _content = content;
  }

  bool shouldAutosave(String content) {
    final lengthChanged = (_savedContent.length - content.length).abs() > 3;
    final crossedWordBoundary =
        (_savedContent.length ~/ 20) != (content.length ~/ 20);
    return lengthChanged || crossedWordBoundary;
  }

  void markSaved() {
    _savedContent = _content;
  }
}
