import '../../expenses/domain/expense.dart';
import '../../trips/domain/trip.dart';
import '../domain/trip_prediction_summary.dart';

class TripPredictionCalculator {
  const TripPredictionCalculator();

  TripPredictionSummary? calculate({
    required Trip trip,
    required List<Expense> expenses,
    DateTime? asOf,
  }) {
    if (expenses.isEmpty || expenses.length < 3) {
      return null;
    }

    final tripStart = trip.startDate;
    final tripEnd = trip.endDate;
    if (tripStart == null || tripEnd == null) {
      return null;
    }

    final today = _dateOnly((asOf ?? DateTime.now()).toLocal());
    final startDate = _dateOnly(tripStart.toLocal());
    final endDate = _dateOnly(tripEnd.toLocal());

    if (!today.isBefore(endDate)) {
      return null;
    }

    final elapsedDays = today.isBefore(startDate)
        ? 0
        : _inclusiveDaysBetween(startDate, today.isAfter(endDate) ? endDate : today);

    if (elapsedDays < 2) {
      return null;
    }

    final remainingDays = endDate.difference(today).inDays;

    final currentSpentByCurrency = <String, double>{};
    final dailySpentByCurrency = <String, Map<DateTime, double>>{};
    for (final expense in expenses) {
      final currency = expense.transactionCurrency.toUpperCase();
      final spentDate = _dateOnly(expense.spentAt.toLocal());
      currentSpentByCurrency[currency] =
          (currentSpentByCurrency[currency] ?? 0) + expense.transactionAmount;
      final dailyMap = dailySpentByCurrency.putIfAbsent(currency, () => {});
      dailyMap[spentDate] = (dailyMap[spentDate] ?? 0) + expense.transactionAmount;
    }

    if (currentSpentByCurrency.isEmpty) {
      return null;
    }

    final burnRateByCurrency = <String, double>{};
    final forecastTotalByCurrency = <String, double>{};

    currentSpentByCurrency.forEach((currency, currentSpent) {
      final dailyTotals = (dailySpentByCurrency[currency] ?? const <DateTime, double>{})
          .entries
          .toList(growable: false)
        ..sort((a, b) => a.key.compareTo(b.key));

      final weightedDailySpend = _weightedDailySpend(dailyTotals);
      final burnRate = weightedDailySpend ?? (currentSpent / elapsedDays);

      burnRateByCurrency[currency] = burnRate;
      forecastTotalByCurrency[currency] =
          currentSpent + (burnRate * remainingDays);
    });

    final budgetWarning = _buildBudgetWarning(
      trip: trip,
      forecastTotalByCurrency: forecastTotalByCurrency,
    );

    return TripPredictionSummary(
      elapsedDays: elapsedDays,
      remainingDays: remainingDays,
      burnRateByCurrency: burnRateByCurrency,
      forecastTotalByCurrency: forecastTotalByCurrency,
      hasBudgetWarning: budgetWarning != null,
      budgetWarningMessage: budgetWarning,
    );
  }

  String? _buildBudgetWarning({
    required Trip trip,
    required Map<String, double> forecastTotalByCurrency,
  }) {
    final budget = trip.budget;
    if (budget == null || budget <= 0) {
      return null;
    }

    final budgetCurrency = trip.baseCurrency.trim().toUpperCase();
    if (budgetCurrency.isEmpty) {
      return null;
    }

    final forecastInBudgetCurrency = forecastTotalByCurrency[budgetCurrency];
    if (forecastInBudgetCurrency == null) {
      return null;
    }

    if (forecastInBudgetCurrency > budget) {
      return '\u0645\u0646 \u0627\u0644\u0645\u062a\u0648\u0642\u0639 \u0623\u0646 \u062a\u062a\u062c\u0627\u0648\u0632 \u0645\u064a\u0632\u0627\u0646\u064a\u062a\u0643 \u0627\u0644\u062d\u0627\u0644\u064a\u0629. \u0642\u062f \u062a\u0635\u0644 \u0625\u0644\u0649 \u062d\u062f \u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629 \u0642\u0628\u0644 \u0646\u0647\u0627\u064a\u0629 \u0627\u0644\u0631\u062d\u0644\u0629';
    }

    return null;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _inclusiveDaysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays + 1;
  }

  double? _weightedDailySpend(List<MapEntry<DateTime, double>> dailyTotals) {
    if (dailyTotals.length < 3) {
      return null;
    }

    double weightedSum = 0;
    int weightSum = 0;
    for (var i = 0; i < dailyTotals.length; i++) {
      final weight = i + 1;
      weightedSum += dailyTotals[i].value * weight;
      weightSum += weight;
    }

    if (weightSum == 0) {
      return null;
    }

    return weightedSum / weightSum;
  }
}
