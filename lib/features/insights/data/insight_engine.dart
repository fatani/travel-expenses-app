import '../../expenses/domain/expense.dart';
import '../domain/insight.dart';

class InsightEngine {
  const InsightEngine();

  List<Insight> build(
    List<Expense> expenses, {
    int maxInsights = 2,
    Map<String, String> tripNamesById = const {},
  }) {
    if (expenses.length < 5) {
      return const [];
    }

    final insights = <Insight>[];

    // Priority 1: spend spike signal.
    final spikeInsight = _buildSpikeInsight(expenses, tripNamesById);
    if (spikeInsight != null) {
      insights.add(spikeInsight);
    }

    // Priority 2: category concentration signal.
    final categoryDriftInsight = _buildCategoryDriftInsight(
      expenses,
      tripNamesById,
    );
    if (categoryDriftInsight != null) {
      insights.add(categoryDriftInsight);
    }

    return insights.take(maxInsights).toList(growable: false);
  }

  Insight? _buildSpikeInsight(
    List<Expense> expenses,
    Map<String, String> tripNamesById,
  ) {
    final sorted = expenses.toList(growable: false)
      ..sort((a, b) => a.spentAt.compareTo(b.spentAt));
    final midpoint = sorted.length ~/ 2;
    final firstHalf = sorted.sublist(0, midpoint);
    final secondHalf = sorted.sublist(midpoint);

    if (firstHalf.length < 2 || secondHalf.length < 2) {
      return null;
    }

    final avgFirstHalf = _averageAmount(firstHalf);
    final avgSecondHalf = _averageAmount(secondHalf);

    if (avgFirstHalf <= 0) {
      return null;
    }

    if (avgSecondHalf >= avgFirstHalf * 1.5) {
      final increasePct = avgFirstHalf < 10
        ? null
        : ((avgSecondHalf - avgFirstHalf) / avgFirstHalf * 100).round();
      final contributionsByTrip = <String, double>{};
      for (final expense in secondHalf) {
        contributionsByTrip[expense.tripId] =
            (contributionsByTrip[expense.tripId] ?? 0) +
                _comparableAmount(expense);
      }
      final topTripId = _topTripId(contributionsByTrip);
      return Insight(
        type: InsightType.spike,
        percentage: increasePct,
        multiplier: avgSecondHalf / avgFirstHalf,
        tripId: topTripId,
        tripName: _tripNameFor(topTripId, tripNamesById),
        contributorTripCount: contributionsByTrip.length,
      );
    }

    return null;
  }

  Insight? _buildCategoryDriftInsight(
    List<Expense> expenses,
    Map<String, String> tripNamesById,
  ) {
    final totalsByCategory = <String, double>{};
    double total = 0;

    for (final expense in expenses) {
      final category = expense.category ?? 'Other';
      final amount = _comparableAmount(expense);
      totalsByCategory[category] = (totalsByCategory[category] ?? 0) + amount;
      total += amount;
    }

    if (total <= 0 || totalsByCategory.length < 3) {
      return null;
    }

    final topEntry = totalsByCategory.entries.reduce(
      (left, right) => left.value >= right.value ? left : right,
    );

    final ratio = topEntry.value / total;
    if (ratio >= 0.50) {
      final contributionsByTrip = <String, double>{};
      for (final expense in expenses) {
        final category = expense.category ?? 'Other';
        if (category != topEntry.key) {
          continue;
        }
        contributionsByTrip[expense.tripId] =
            (contributionsByTrip[expense.tripId] ?? 0) +
                _comparableAmount(expense);
      }
      final topTripId = _topTripId(contributionsByTrip);
      return Insight(
        type: InsightType.categoryDrift,
        category: topEntry.key,
        percentage: (ratio * 100).round(),
        tripId: topTripId,
        tripName: _tripNameFor(topTripId, tripNamesById),
        contributorTripCount: contributionsByTrip.length,
      );
    }

    return null;
  }

  double _averageAmount(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return 0;
    }
    final total = expenses.fold<double>(
      0,
      (sum, expense) => sum + _comparableAmount(expense),
    );
    return total / expenses.length;
  }

  double _comparableAmount(Expense expense) {
    return expense.billedAmount ?? expense.amount;
  }

  String? _topTripId(Map<String, double> contributionsByTrip) {
    String? topTripId;
    double topAmount = -1;

    contributionsByTrip.forEach((tripId, amount) {
      if (amount > topAmount) {
        topAmount = amount;
        topTripId = tripId;
        return;
      }
      if (amount == topAmount && topTripId != null && tripId.compareTo(topTripId!) < 0) {
        topTripId = tripId;
      }
    });

    return topTripId;
  }

  String? _tripNameFor(String? tripId, Map<String, String> tripNamesById) {
    if (tripId == null) {
      return null;
    }
    return tripNamesById[tripId];
  }
}
