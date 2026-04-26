enum TripDecisionActionType { burnRisk, spendSpike, categoryConcentration }

class TripDecisionAction {
  const TripDecisionAction({
    required this.type,
    this.category,
    this.percentage,
  });

  final TripDecisionActionType type;
  final String? category;
  final int? percentage;
}

class TripPredictionSummary {
  const TripPredictionSummary({
    required this.elapsedDays,
    required this.remainingDays,
    required this.isTripEnded,
    required this.totalSpendByCurrency,
    required this.burnRateByCurrency,
    required this.forecastTotalByCurrency,
    required this.actions,
  });

  final int elapsedDays;
  final int remainingDays;
  final bool isTripEnded;
  final Map<String, double> totalSpendByCurrency;
  final Map<String, double> burnRateByCurrency;
  final Map<String, double> forecastTotalByCurrency;
  final List<TripDecisionAction> actions;
}
