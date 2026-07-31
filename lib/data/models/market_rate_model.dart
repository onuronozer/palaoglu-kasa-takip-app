class MarketRateModel {
  const MarketRateModel({
    required this.code,
    required this.label,
    required this.buy,
    required this.sell,
    required this.updatedText,
    required this.direction,
  });

  final String code;
  final String label;
  final double buy;
  final double sell;
  final String updatedText;
  final String direction;
}
