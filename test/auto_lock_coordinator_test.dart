import 'package:flutter_test/flutter_test.dart';
import 'package:local_keep/services/auto_lock_coordinator.dart';

void main() {
  test('file operations prevent locking while active', () {
    final coordinator = AutoLockCoordinator();

    expect(coordinator.shouldSkipLock, isFalse);
    coordinator.setPickingFile(true);
    expect(coordinator.shouldSkipLock, isTrue);
    coordinator.setPickingFile(false);
    expect(coordinator.shouldSkipLock, isFalse);
  });
}
