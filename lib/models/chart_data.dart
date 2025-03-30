class ChartData {
  final DateTime date;
  final double value;

  ChartData(this.date, this.value);
}

class Stats {
  final int totalCount;
  final int totalValue;
  final int averageCount;
  final int averageValue;

  Stats({
    required this.totalCount,
    required this.totalValue,
    required this.averageCount,
    required this.averageValue,
  });
}
