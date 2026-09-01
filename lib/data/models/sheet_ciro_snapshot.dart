class SheetCiroSnapshot {
  const SheetCiroSnapshot({
    required this.monthKey,
    required this.hasSource,
    required this.ciroByDate,
  });

  const SheetCiroSnapshot.noSource(this.monthKey)
      : hasSource = false,
        ciroByDate = const {};

  final String monthKey;
  final bool hasSource;
  final Map<String, double> ciroByDate;
}
