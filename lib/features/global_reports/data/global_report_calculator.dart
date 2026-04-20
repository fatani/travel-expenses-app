import '../../expenses/domain/expense.dart';
import '../../reports/domain/report_bucket.dart';
import '../../trips/domain/trip.dart';
import '../domain/global_report_summary.dart';

class GlobalReportCalculator {
  const GlobalReportCalculator();

  GlobalReportSummary calculate({
    required List<Trip> trips,
    required List<Expense> expenses,
  }) {
    final totalTrips = trips.length;
    final tripIds = trips.map((trip) => trip.id).toSet();
    final relevantExpenses = expenses
        .where((expense) => tripIds.contains(expense.tripId))
        .toList(growable: false);
    final activeTrips = relevantExpenses.map((expense) => expense.tripId).toSet().length;

    final totalExpenseCount = relevantExpenses.length;
    final internationalExpenseCount =
        relevantExpenses.where((expense) => expense.isInternational).length;
    final domesticExpenseCount = totalExpenseCount - internationalExpenseCount;

    final billedByCurrency = <String, _Accumulator>{};
    final categoryTotals = <String, _Accumulator>{};
    final paymentChannelUsage = <String, _UsageAccumulator>{};
    final paymentNetworkUsage = <String, _UsageAccumulator>{};

    for (final expense in relevantExpenses) {
      final billedCurrency =
          (expense.billedCurrency ?? expense.currencyCode).toUpperCase();
      final billedAmount = expense.billedAmount ?? expense.amount;
      final category = expense.category ?? 'Other';
      final paymentChannel =
          (expense.paymentChannel?.isNotEmpty == true)
              ? expense.paymentChannel!
              : 'Other';
      final paymentNetwork =
          (expense.paymentNetwork?.isNotEmpty == true)
              ? expense.paymentNetwork!
              : 'Other';

      billedByCurrency
          .putIfAbsent(billedCurrency, () => _Accumulator())
          .add(billedAmount);
      categoryTotals.putIfAbsent(category, () => _Accumulator()).add(billedAmount);
      paymentChannelUsage
          .putIfAbsent(paymentChannel, () => _UsageAccumulator())
          .add(billedAmount);
      paymentNetworkUsage
          .putIfAbsent(paymentNetwork, () => _UsageAccumulator())
          .add(billedAmount);
    }

    final totalBilledByCurrency = _toBuckets(billedByCurrency);
    final isSingleTrip = totalTrips == 1;
    final topCategory = isSingleTrip ? null : _topAccumulatorKey(categoryTotals);
    final mostUsedPaymentChannel =
      isSingleTrip ? null : _topUsageKey(paymentChannelUsage);
    final mostUsedPaymentNetwork =
      isSingleTrip ? null : _topUsageKey(paymentNetworkUsage);
    final dominantCurrency =
        totalBilledByCurrency.isEmpty ? null : totalBilledByCurrency.first.currency;
    final trackedTripDays = trips.fold<int>(
      0,
      (sum, trip) => sum + _trackedDaysForTrip(trip),
    );

    final averageSpendPerTripByCurrency = _buildAveragePerTripMetrics(
      totalBilledByCurrency: totalBilledByCurrency,
      tripCount: totalTrips,
    );
    final averageDailySpendByCurrency = _buildAverageDailyMetrics(
      totalBilledByCurrency: totalBilledByCurrency,
      trackedTripDays: trackedTripDays,
    );
    final smartInsights = _buildSmartInsights(
      totalExpenseCount: totalExpenseCount,
      totalTripCount: totalTrips,
      internationalExpenseCount: internationalExpenseCount,
      domesticExpenseCount: domesticExpenseCount,
      mostUsedPaymentChannel: mostUsedPaymentChannel,
      mostUsedPaymentChannelCount:
          paymentChannelUsage[mostUsedPaymentChannel]?.count,
      dominantCategory: topCategory,
      totalBilledByCurrency: totalBilledByCurrency,
      averageSpendPerTripByCurrency: averageSpendPerTripByCurrency,
    );

    return GlobalReportSummary(
      totalTrips: totalTrips,
      activeTrips: activeTrips,
      totalExpenseCount: totalExpenseCount,
      internationalExpenseCount: internationalExpenseCount,
      domesticExpenseCount: domesticExpenseCount,
      trackedTripDays: trackedTripDays,
      totalBilledByCurrency: totalBilledByCurrency,
      averageSpendPerTripByCurrency: averageSpendPerTripByCurrency,
      averageDailySpendByCurrency: averageDailySpendByCurrency,
      topCategory: topCategory,
      mostUsedPaymentChannel: mostUsedPaymentChannel,
      mostUsedPaymentNetwork: mostUsedPaymentNetwork,
      dominantCurrency: dominantCurrency,
      dominantCategory: topCategory,
      smartInsights: smartInsights,
    );
  }

  List<ReportBucket> _toBuckets(Map<String, _Accumulator> map) {
    final buckets = map.entries
        .map(
          (entry) => ReportBucket(
            key: entry.key,
            currency: entry.key,
            totalAmount: entry.value.total,
            count: entry.value.count,
          ),
        )
        .toList();
    buckets.sort((a, b) {
      final amountComparison = b.totalAmount.compareTo(a.totalAmount);
      if (amountComparison != 0) {
        return amountComparison;
      }
      return a.currency.compareTo(b.currency);
    });
    return buckets;
  }

  List<GlobalCurrencyMetric> _buildAveragePerTripMetrics({
    required List<ReportBucket> totalBilledByCurrency,
    required int tripCount,
  }) {
    if (tripCount <= 0) {
      return const [];
    }

    return totalBilledByCurrency
        .map(
          (bucket) => GlobalCurrencyMetric(
            currency: bucket.currency,
            amount: bucket.totalAmount / tripCount,
          ),
        )
        .toList(growable: false);
  }

  List<GlobalCurrencyMetric> _buildAverageDailyMetrics({
    required List<ReportBucket> totalBilledByCurrency,
    required int trackedTripDays,
  }) {
    if (trackedTripDays <= 0) {
      return const [];
    }

    return totalBilledByCurrency
        .map(
          (bucket) => GlobalCurrencyMetric(
            currency: bucket.currency,
            amount: bucket.totalAmount / trackedTripDays,
          ),
        )
        .toList(growable: false);
  }

  String? _topAccumulatorKey(Map<String, _Accumulator> map) {
    String? topKey;
    double topTotal = -1;

    map.forEach((key, accumulator) {
      if (accumulator.total > topTotal) {
        topTotal = accumulator.total;
        topKey = key;
        return;
      }
      if (accumulator.total == topTotal && topKey != null && key.compareTo(topKey!) < 0) {
        topKey = key;
      }
    });

    return topKey;
  }

  String? _topUsageKey(Map<String, _UsageAccumulator> map) {
    String? topKey;
    _UsageAccumulator? topUsage;

    map.forEach((key, usage) {
      if (topUsage == null || _compareUsage(usage, key, topUsage!, topKey!) < 0) {
        topKey = key;
        topUsage = usage;
      }
    });

    return topKey;
  }

  int _compareUsage(
    _UsageAccumulator left,
    String leftKey,
    _UsageAccumulator right,
    String rightKey,
  ) {
    final countComparison = right.count.compareTo(left.count);
    if (countComparison != 0) {
      return countComparison;
    }

    final amountComparison = right.total.compareTo(left.total);
    if (amountComparison != 0) {
      return amountComparison;
    }

    return leftKey.compareTo(rightKey);
  }

  int _trackedDaysForTrip(Trip trip) {
    final startDate = trip.startDate;
    final endDate = trip.endDate;
    if (startDate == null || endDate == null) {
      return 0;
    }
    if (endDate.isBefore(startDate)) {
      return 0;
    }
    return endDate.difference(startDate).inDays + 1;
  }

  List<GlobalReportInsight> _buildSmartInsights({
    required int totalExpenseCount,
    required int totalTripCount,
    required int internationalExpenseCount,
    required int domesticExpenseCount,
    required String? mostUsedPaymentChannel,
    required int? mostUsedPaymentChannelCount,
    required String? dominantCategory,
    required List<ReportBucket> totalBilledByCurrency,
    required List<GlobalCurrencyMetric> averageSpendPerTripByCurrency,
  }) {
    final insights = <GlobalReportInsight>[];
    final isSingleTrip = totalTripCount == 1;

    if (isSingleTrip) {
      if (totalBilledByCurrency.isNotEmpty) {
        insights.add(
          GlobalReportInsight(
            type: GlobalReportInsightType.currencyDistribution,
            percentage: totalBilledByCurrency.length,
          ),
        );
      }

      if (totalExpenseCount > 0) {
        insights.add(
          GlobalReportInsight(
            type: GlobalReportInsightType.internationalDomesticRatio,
            percentage: ((internationalExpenseCount / totalExpenseCount) * 100)
                .round(),
          ),
        );
      }

      return insights.take(3).toList(growable: false);
    }

    if (mostUsedPaymentChannel != null &&
        mostUsedPaymentChannelCount != null &&
        totalExpenseCount > 0) {
      insights.add(
        GlobalReportInsight(
          type: GlobalReportInsightType.dominantPaymentChannel,
          subject: mostUsedPaymentChannel,
          percentage: ((mostUsedPaymentChannelCount / totalExpenseCount) * 100)
              .round(),
        ),
      );
    }

    if (dominantCategory != null) {
      insights.add(
        GlobalReportInsight(
          type: GlobalReportInsightType.dominantCategory,
          subject: dominantCategory,
        ),
      );
    }

    if (totalTripCount > 0 &&
        averageSpendPerTripByCurrency.isNotEmpty &&
        totalBilledByCurrency.length == 1) {
      final average = averageSpendPerTripByCurrency.first;
      insights.add(
        GlobalReportInsight(
          type: GlobalReportInsightType.averageSpendPerTrip,
          amount: average.amount,
          currency: average.currency,
        ),
      );
    } else if (totalBilledByCurrency.isNotEmpty) {
      final totalBilled = totalBilledByCurrency.fold<double>(
        0,
        (sum, bucket) => sum + bucket.totalAmount,
      );
      final dominant = totalBilledByCurrency.first;
      insights.add(
        GlobalReportInsight(
          type: GlobalReportInsightType.dominantCurrency,
          subject: dominant.currency,
          percentage: totalBilled <= 0
              ? 0
              : ((dominant.totalAmount / totalBilled) * 100).round(),
        ),
      );
    }

    return insights.take(3).toList(growable: false);
  }
}

class _Accumulator {
  double total = 0;
  int count = 0;

  void add(double amount) {
    total += amount;
    count++;
  }
}

class _UsageAccumulator {
  double total = 0;
  int count = 0;

  void add(double amount) {
    total += amount;
    count++;
  }
}
