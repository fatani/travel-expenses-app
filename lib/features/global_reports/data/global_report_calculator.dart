import '../../expenses/domain/expense.dart';
import '../../insights/data/insight_engine.dart';
import '../../insights/domain/insight.dart';
import '../../reports/domain/report_bucket.dart';
import '../../trips/domain/trip.dart';
import '../domain/global_report_summary.dart';

class GlobalReportCalculator {
  const GlobalReportCalculator({InsightEngine insightEngine = const InsightEngine()})
    : _insightEngine = insightEngine;

  final InsightEngine _insightEngine;

  GlobalReportSummary calculate({
    required List<Trip> trips,
    required List<Expense> expenses,
  }) {
    final totalTrips = trips.length;
    final tripNamesById = {
      for (final trip in trips) trip.id: trip.name,
    };
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
      final billedCurrency = expense.transactionCurrency.toUpperCase();
      final billedAmount = expense.transactionAmount;
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
      uniqueTransactionCurrencyCount: totalBilledByCurrency.length,
      uniqueCategoryCount: categoryTotals.length,
      uniquePaymentChannelCount: paymentChannelUsage.length,
      uniquePaymentNetworkCount: paymentNetworkUsage.length,
    );
    final behavioralInsights = relevantExpenses.length < 5
      ? const <Insight>[]
        : _insightEngine.build(
            relevantExpenses,
            maxInsights: 2,
            tripNamesById: tripNamesById,
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
      uniqueCategoryCount: categoryTotals.length,
      uniquePaymentChannelCount: paymentChannelUsage.length,
      uniquePaymentNetworkCount: paymentNetworkUsage.length,
      uniqueTransactionCurrencyCount: totalBilledByCurrency.length,
      smartInsights: smartInsights,
      behavioralInsights: behavioralInsights,
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
    required int uniqueTransactionCurrencyCount,
    required int uniqueCategoryCount,
    required int uniquePaymentChannelCount,
    required int uniquePaymentNetworkCount,
  }) {
    if (totalExpenseCount < 3) {
      return const [];
    }

    final hasMeaningfulVariation =
        uniqueTransactionCurrencyCount > 1 ||
        uniqueCategoryCount > 1 ||
        uniquePaymentChannelCount > 1 ||
        uniquePaymentNetworkCount > 1;
    if (!hasMeaningfulVariation) {
      return const [];
    }

    final insights = <GlobalReportInsight>[];

    if (uniqueTransactionCurrencyCount > 1) {
      insights.add(
        GlobalReportInsight(
          type: GlobalReportInsightType.currencyDistribution,
          percentage: uniqueTransactionCurrencyCount,
        ),
      );
    }

    if (uniqueCategoryCount > 1) {
      insights.add(
        GlobalReportInsight(
          type: GlobalReportInsightType.categoryVariation,
          percentage: uniqueCategoryCount,
        ),
      );
    }

    if (uniquePaymentChannelCount > 1 || uniquePaymentNetworkCount > 1) {
      insights.add(
        const GlobalReportInsight(
          type: GlobalReportInsightType.paymentVariation,
        ),
      );
    }

    return insights.take(2).toList(growable: false);
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
