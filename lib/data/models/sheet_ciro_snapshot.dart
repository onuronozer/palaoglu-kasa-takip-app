class SheetCiroSnapshot {
  const SheetCiroSnapshot({
    required this.monthKey,
    required this.hasSource,
    required this.ciroByDate,
    this.checkedAt,
  });

  const SheetCiroSnapshot.noSource(this.monthKey, {this.checkedAt})
      : hasSource = false,
        ciroByDate = const {};

  final String monthKey;
  final bool hasSource;
  final Map<String, double> ciroByDate;
  final DateTime? checkedAt;
}
