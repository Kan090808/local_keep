import 'package:flutter_test/flutter_test.dart';
import 'package:local_keep/services/auto_lock_coordinator.dart';

void main() {
  test('operation leases prevent locking until all leases end', () {
    final coordinator = AutoLockCoordinator();

    expect(coordinator.shouldSkipLock, isFalse);
    final release = coordinator.beginOperation();
    expect(coordinator.shouldSkipLock, isTrue);
    release();
    expect(coordinator.shouldSkipLock, isFalse);
  });
}
