import 'dart:async';
import 'dart:collection';

enum OperationPriority { low, medium, high, critical }

class PendingOperation {
  final String id;
  final Function operation;
  final OperationPriority priority;
  final DateTime createdAt;

  PendingOperation({
    required this.id,
    required this.operation,
    required this.priority,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class SmartDebounceService {
  static final Map<String, Timer> _timers = {};
  static final Queue<PendingOperation> _operationQueue =
      Queue<PendingOperation>();
  static bool _isProcessing = false;

  // Configure debounce delays based on operation type
  static const Map<OperationPriority, Duration> _debounceDelays = {
    OperationPriority.critical: Duration(milliseconds: 50), // Almost immediate
    OperationPriority.high: Duration(milliseconds: 200), // UI updates
    OperationPriority.medium: Duration(milliseconds: 800), // Auto-save
    OperationPriority.low: Duration(milliseconds: 2000), // Background tasks
  };

  // Debounce an operation with priority
  static void debounce({
    required String key,
    required Function operation,
    OperationPriority priority = OperationPriority.medium,
    Duration? customDelay,
  }) {
    // Cancel existing timer for this key
    _timers[key]?.cancel();

    final delay = customDelay ?? _debounceDelays[priority]!;

    _timers[key] = Timer(delay, () {
      _queueOperation(
        PendingOperation(id: key, operation: operation, priority: priority),
      );
      _timers.remove(key);
    });
  }

  // Queue operation for processing
  static void _queueOperation(PendingOperation operation) {
    _operationQueue.add(operation);
    _processQueue();
  }

  // Process operations based on priority
  static Future<void> _processQueue() async {
    if (_isProcessing || _operationQueue.isEmpty) return;

    _isProcessing = true;

    // Sort by priority and age
    final operations = _operationQueue.toList();
    operations.sort((a, b) {
      // First sort by priority (critical -> low)
      final priorityComparison = _getPriorityValue(
        b.priority,
      ).compareTo(_getPriorityValue(a.priority));
      if (priorityComparison != 0) return priorityComparison;

      // Then by age (older first)
      return a.createdAt.compareTo(b.createdAt);
    });

    _operationQueue.clear();

    // Process operations in batches to avoid blocking
    final batchSize = 3;
    for (int i = 0; i < operations.length; i += batchSize) {
      final batch = operations.skip(i).take(batchSize);

      await Future.wait(
        batch.map((op) async {
          try {
            await op.operation();
          } catch (e) {
            print('Error executing operation ${op.id}: $e');
          }
        }),
      );

      // Yield control between batches
      if (i + batchSize < operations.length) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    _isProcessing = false;

    // Process any new operations that were queued during processing
    if (_operationQueue.isNotEmpty) {
      _processQueue();
    }
  }

  static int _getPriorityValue(OperationPriority priority) {
    switch (priority) {
      case OperationPriority.critical:
        return 4;
      case OperationPriority.high:
        return 3;
      case OperationPriority.medium:
        return 2;
      case OperationPriority.low:
        return 1;
    }
  }

  // Cancel all pending operations for a key
  static void cancel(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _operationQueue.removeWhere((op) => op.id == key);
  }

  // Cancel all operations
  static void cancelAll() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _operationQueue.clear();
  }

  // Get pending operation count
  static int get pendingCount => _timers.length + _operationQueue.length;

  // Check if operations are being processed
  static bool get isProcessing => _isProcessing;
}
