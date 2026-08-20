import 'package:flutter_test/flutter_test.dart';
import 'package:local_keep/services/note_draft.dart';

void main() {
  test('draft tracks edits and saves its current content', () {
    final draft = NoteDraft('hello');

    expect(draft.isDirty, isFalse);
    draft.updateContent('hello world');
    expect(draft.isDirty, isTrue);
    expect(draft.shouldAutosave('hello world'), isTrue);

    draft.markSaved();
    expect(draft.isDirty, isFalse);
  });

  test('small edits stay below the existing autosave threshold', () {
    final draft = NoteDraft('hello');

    draft.updateContent('hello!');

    expect(draft.shouldAutosave('hello!'), isFalse);
  });
}
