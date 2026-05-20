class TripPredictionSummary {
  const TripPredictionSummary({
    required this.elapsedDays,
    required this.remainingDays,
    required this.burnRateByCurrency,
    required this.forecastTotalByCurrency,
    required this.hasBudgetWarning,
    required this.budgetWarningMessage,
  });

  final int elapsedDays;
  final int remainingDays;
  final Map<String, double> burnRateByCurrency;
  final Map<String, double> forecastTotalByCurrency;
  final bool hasBudgetWarning;
  final String? budgetWarningMessage;
}
