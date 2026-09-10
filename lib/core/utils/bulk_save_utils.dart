class BulkSaveResult<T> {
  final List<T> saved = [];
  final Map<T, Object> failed = {};
}

Future<BulkSaveResult<T>> saveBulkRows<T>(
  List<T> rows, {
  required Future<void> Function(T row) save,
  required bool Function() canContinue,
}) async {
  final result = BulkSaveResult<T>();
  for (final row in List<T>.of(rows)) {
    if (!canContinue()) break;
    try {
      await save(row);
      result.saved.add(row);
    } catch (error) {
      result.failed[row] = error;
    }
  }
  return result;
}
