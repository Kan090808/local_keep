class TransactionalReplacement {
  static Future<void> replace<T>({
    required List<T> current,
    required List<T> incoming,
    required Future<void> Function(List<T> values) apply,
  }) async {
    final snapshot = List<T>.from(current);
    try {
      await apply(List<T>.from(incoming));
    } catch (error) {
      await apply(snapshot);
      rethrow;
    }
  }
}
