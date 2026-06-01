class TripPredictionSummary {
  const TripPredictionSummary({
    required this.elapsedDays,
    required this.remainingDays,
    required this.burnRateByCurrency,
    required this.forecastTotalByCurrency,
    required this.hasBudgetWarning,
  });

  final int elapsedDays;
  final int remainingDays;
  final Map<String, double> burnRateByCurrency;
  final Map<String, double> forecastTotalByCurrency;
  final bool hasBudgetWarning;
}
