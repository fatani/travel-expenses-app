import '../../expenses/domain/expense.dart';
import '../../insights/data/insight_engine.dart';
import '../../insights/domain/insight.dart';
import '../domain/report_bucket.dart';
import '../domain/trip_report_summary.dart';

/// Computes a [TripReportSummary] from a list of [Expense] objects.
///
/// All currency groupings are kept separate — amounts in different currencies
/// are never summed together.
class TripReportCalculator {
  const TripReportCalculator({InsightEngine insightEngine = const InsightEngine()})
      : _insightEngine = insightEngine;

  final InsightEngine _insightEngine;

  TripReportSummary calculate({
    required String tripId,
    required String tripName,
    required List<Expense> expenses,
  }) {
    if (expenses.isEmpty) {
      return TripReportSummary(
        tripId: tripId,
        tripName: tripName,
        totalExpenseCount: 0,
        internationalExpenseCount: 0,
        domesticExpenseCount: 0,
        totalBilledByCurrency: const [],
        totalFeesByCurrency: const [],
        topCategory: null,
        topPaymentNetwork: null,
        topPaymentChannel: null,
        byCategory: const [],
        byTransactionCurrency: const [],
        byPaymentNetwork: const [],
        byPaymentChannel: const [],
        smartInsights: const [],
      );
    }

    final int total = expenses.length;
    final int international = expenses.where((e) => e.isInternational).length;
    final int domestic = total - international;

    // --- totals grouped by transaction currency -------------------------------
    final billedByCurrency = <String, _Accumulator>{};
    for (final e in expenses) {
      final currency = e.transactionCurrency.toUpperCase();
      final amount = e.transactionAmount;
      billedByCurrency
          .putIfAbsent(currency, () => _Accumulator())
          .add(amount);
    }

    // --- fees grouped by fee currency ----------------------------------------
    final feesByCurrency = <String, _Accumulator>{};
    for (final e in expenses) {
      if (e.feesAmount != null && e.feesAmount! > 0) {
        final currency =
            (e.feesCurrency ?? e.currencyCode).toUpperCase();
        feesByCurrency
            .putIfAbsent(currency, () => _Accumulator())
            .add(e.feesAmount!);
      }
    }

    // --- by category (key = "categoryName|CURRENCY") -------------------------
    // We group by category + transaction currency to avoid currency mixing.
    final categoryMap = <String, Map<String, _Accumulator>>{};
    for (final e in expenses) {
      final cat = e.category ?? 'Other';
      final currency = e.transactionCurrency.toUpperCase();
      final amount = e.transactionAmount;
      categoryMap
          .putIfAbsent(cat, () => {})
          .putIfAbsent(currency, () => _Accumulator())
          .add(amount);
    }

    // --- by transaction currency ---------------------------------------------
    final txCurrencyMap = <String, _Accumulator>{};
    for (final e in expenses) {
      final currency = e.transactionCurrency.toUpperCase();
      txCurrencyMap
          .putIfAbsent(currency, () => _Accumulator())
        .add(e.transactionAmount);
    }

    // --- by payment network --------------------------------------------------
    final networkMap = <String, Map<String, _Accumulator>>{};
    for (final e in expenses) {
      final network = (e.paymentNetwork?.isNotEmpty == true)
          ? e.paymentNetwork!
          : 'Other';
      final currency = e.transactionCurrency.toUpperCase();
      networkMap
          .putIfAbsent(network, () => {})
          .putIfAbsent(currency, () => _Accumulator())
        .add(e.transactionAmount);
    }

    // --- by payment channel --------------------------------------------------
    final channelMap = <String, Map<String, _Accumulator>>{};
    for (final e in expenses) {
      final channel = (e.paymentChannel?.isNotEmpty == true)
          ? e.paymentChannel!
          : 'Other';
      final currency = e.transactionCurrency.toUpperCase();
      channelMap
          .putIfAbsent(channel, () => {})
          .putIfAbsent(currency, () => _Accumulator())
        .add(e.transactionAmount);
    }

    // --- top category (by total billed, first currency encountered) ----------
    String? topCategory;
    double topAmount = -1;
    categoryMap.forEach((cat, currencyAccumulators) {
      final catTotal = currencyAccumulators.values
          .fold<double>(0, (sum, acc) => sum + acc.total);
      if (catTotal > topAmount) {
        topAmount = catTotal;
        topCategory = cat;
      }
    });

    final byCategoryBuckets = _toNestedBuckets(categoryMap);
    final byTransactionCurrencyBuckets =
        _toBuckets(txCurrencyMap, keyFn: (k) => k);
    final byPaymentNetworkBuckets = _toNestedBuckets(networkMap);
    final byPaymentChannelBuckets = _toNestedBuckets(channelMap);
    final totalBilledByCurrencyBuckets =
        _toBuckets(billedByCurrency, keyFn: (k) => k);
    final totalFeesByCurrencyBuckets =
        _toBuckets(feesByCurrency, keyFn: (k) => k);
    final topPaymentNetwork = _topNestedKey(networkMap);
    final topPaymentChannel = _topNestedKey(channelMap);
    final smartInsights = (expenses.length < 5
            ? const <Insight>[]
            : _insightEngine.build(
                expenses,
                maxInsights: 1,
                tripNamesById: {tripId: tripName},
              ))
        .map(_toTripInsight)
        .toList(growable: false);

    return TripReportSummary(
      tripId: tripId,
      tripName: tripName,
      totalExpenseCount: total,
      internationalExpenseCount: international,
      domesticExpenseCount: domestic,
      totalBilledByCurrency: totalBilledByCurrencyBuckets,
      totalFeesByCurrency: totalFeesByCurrencyBuckets,
      topCategory: topCategory,
      topPaymentNetwork: topPaymentNetwork,
      topPaymentChannel: topPaymentChannel,
      byCategory: byCategoryBuckets,
      byTransactionCurrency: byTransactionCurrencyBuckets,
      byPaymentNetwork: byPaymentNetworkBuckets,
      byPaymentChannel: byPaymentChannelBuckets,
      smartInsights: smartInsights,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<ReportBucket> _toBuckets(
    Map<String, _Accumulator> map, {
    required String Function(String) keyFn,
  }) {
    return map.entries
        .map((e) => ReportBucket(
              key: keyFn(e.key),
              currency: e.key,
              totalAmount: e.value.total,
              count: e.value.count,
            ))
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  /// Expands a nested map (outerKey → currency → Accumulator) into flat buckets.
  /// The bucket key is the outer key; currency is kept per bucket.
  List<ReportBucket> _toNestedBuckets(
    Map<String, Map<String, _Accumulator>> map,
  ) {
    final buckets = <ReportBucket>[];
    map.forEach((outerKey, currencyMap) {
      currencyMap.forEach((currency, acc) {
        buckets.add(ReportBucket(
          key: outerKey,
          currency: currency,
          totalAmount: acc.total,
          count: acc.count,
        ));
      });
    });
    buckets.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return buckets;
  }

  String? _topNestedKey(Map<String, Map<String, _Accumulator>> map) {
    String? topKey;
    double topTotal = -1;
    map.forEach((key, nested) {
      final total = nested.values.fold<double>(
        0,
        (sum, accumulator) => sum + accumulator.total,
      );
      if (total > topTotal) {
        topTotal = total;
        topKey = key;
      }
    });
    return topKey;
  }

  TripReportInsight _toTripInsight(Insight insight) {
    switch (insight.type) {
      case InsightType.spike:
        return TripReportInsight(
          type: TripReportInsightType.spike,
          subject: insight.tripName,
          percentage: insight.percentage,
        );
      case InsightType.categoryDrift:
        return TripReportInsight(
          type: TripReportInsightType.categoryDrift,
          subject: insight.category,
          percentage: insight.percentage,
        );
      case InsightType.fees:
        return TripReportInsight(
          type: TripReportInsightType.feesPercentage,
          percentage: insight.percentage,
        );
    }
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
