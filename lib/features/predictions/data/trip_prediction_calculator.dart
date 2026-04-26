import 'dart:math' as math;

import '../../expenses/domain/expense.dart';
import '../../insights/data/insight_engine.dart';
import '../../insights/domain/insight.dart';
import '../../trips/domain/trip.dart';
import '../domain/trip_prediction_summary.dart';

class TripPredictionCalculator {
  const TripPredictionCalculator({
    InsightEngine insightEngine = const InsightEngine(),
  }) : _insightEngine = insightEngine;

  final InsightEngine _insightEngine;

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
    final isTripEnded = today.isAfter(endDate);

    final rawElapsedDays = today.isAfter(endDate)
        ? endDate.difference(startDate).inDays
        : today.difference(startDate).inDays;
    final totalTripDays = endDate.difference(startDate).inDays;
    final elapsedDays = math.max(1, math.min(rawElapsedDays, totalTripDays));

    if (elapsedDays < 2) {
      return null;
    }

    final remainingDays = math.max(0, endDate.difference(today).inDays);

    final totalSpendByCurrency = <String, double>{};
    for (final expense in expenses) {
      final currency = expense.transactionCurrency.toUpperCase();
      totalSpendByCurrency[currency] =
          (totalSpendByCurrency[currency] ?? 0) + expense.transactionAmount;
    }

    if (totalSpendByCurrency.isEmpty) {
      return null;
    }

    final burnRateByCurrency = <String, double>{};
    final forecastTotalByCurrency = <String, double>{};

    totalSpendByCurrency.forEach((currency, currentSpent) {
      final burnRate = currentSpent / elapsedDays;
      burnRateByCurrency[currency] = burnRate;
      forecastTotalByCurrency[currency] =
          currentSpent + (burnRate * remainingDays);
    });

    final insights = _insightEngine.build(expenses, maxInsights: 2);
    final actions = _buildActions(
      totalSpendByCurrency: totalSpendByCurrency,
      burnRateByCurrency: burnRateByCurrency,
      remainingDays: remainingDays,
      insights: insights,
    );

    return TripPredictionSummary(
      elapsedDays: elapsedDays,
      remainingDays: remainingDays,
      isTripEnded: isTripEnded,
      totalSpendByCurrency: totalSpendByCurrency,
      burnRateByCurrency: burnRateByCurrency,
      forecastTotalByCurrency: forecastTotalByCurrency,
      actions: actions,
    );
  }

  List<TripDecisionAction> _buildActions({
    required Map<String, double> totalSpendByCurrency,
    required Map<String, double> burnRateByCurrency,
    required int remainingDays,
    required List<Insight> insights,
  }) {
    final prioritized = <TripDecisionAction>[];

    final hasBurnRisk = totalSpendByCurrency.entries.any((entry) {
      final burnRate = burnRateByCurrency[entry.key] ?? 0;
      return (burnRate * remainingDays) > entry.value;
    });
    if (hasBurnRisk) {
      prioritized.add(
        const TripDecisionAction(type: TripDecisionActionType.burnRisk),
      );
    }

    final spikeInsight = insights.where(
      (insight) => insight.type == InsightType.spike,
    );
    if (spikeInsight.isNotEmpty) {
      prioritized.add(
        TripDecisionAction(
          type: TripDecisionActionType.spendSpike,
          // Keep display context causal even when exact spike percentage is omitted.
          percentage: spikeInsight.first.percentage ?? 50,
        ),
      );
    }

    final categoryInsight = insights.where(
      (insight) => insight.type == InsightType.categoryDrift,
    );
    if (categoryInsight.isNotEmpty &&
        (categoryInsight.first.percentage ?? 0) >= 50) {
      prioritized.add(
        TripDecisionAction(
          type: TripDecisionActionType.categoryConcentration,
          category: categoryInsight.first.category,
          percentage: categoryInsight.first.percentage,
        ),
      );
    }

    return prioritized.take(2).toList(growable: false);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
