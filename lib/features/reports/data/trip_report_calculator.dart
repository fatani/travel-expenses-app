import '../../expenses/domain/expense.dart';
import '../domain/report_bucket.dart';
import '../domain/trip_report_summary.dart';

/// Computes a [TripReportSummary] from a list of [Expense] objects.
///
/// All currency groupings are kept separate — amounts in different currencies
/// are never summed together.
class TripReportCalculator {
  const TripReportCalculator();

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
    final int international =
        expenses.where((e) => e.isInternational).length;
    final int domestic = total - international;
    final bool hasInternationalFees = expenses.any(
      (e) => e.isInternational && (e.feesAmount ?? 0) > 0,
    );

    // --- billed totals (billedAmount ?? amount) grouped by currency ----------
    final billedByCurrency = <String, _Accumulator>{};
    for (final e in expenses) {
      final currency = (e.billedCurrency ?? e.currencyCode).toUpperCase();
      final amount = e.billedAmount ?? e.amount;
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
    // We group by category + billing currency to avoid currency mixing.
    final categoryMap = <String, Map<String, _Accumulator>>{};
    for (final e in expenses) {
      final cat = e.category ?? 'Other';
      final currency = (e.billedCurrency ?? e.currencyCode).toUpperCase();
      final amount = e.billedAmount ?? e.amount;
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
      final currency = (e.billedCurrency ?? e.currencyCode).toUpperCase();
      networkMap
          .putIfAbsent(network, () => {})
          .putIfAbsent(currency, () => _Accumulator())
          .add(e.billedAmount ?? e.amount);
    }

    // --- by payment channel --------------------------------------------------
    final channelMap = <String, Map<String, _Accumulator>>{};
    for (final e in expenses) {
      final channel = (e.paymentChannel?.isNotEmpty == true)
          ? e.paymentChannel!
          : 'Other';
      final currency = (e.billedCurrency ?? e.currencyCode).toUpperCase();
      channelMap
          .putIfAbsent(channel, () => {})
          .putIfAbsent(currency, () => _Accumulator())
          .add(e.billedAmount ?? e.amount);
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
    final totalBilledAmount = totalBilledByCurrencyBuckets.fold<double>(
      0, (sum, b) => sum + b.totalAmount);
    final totalFeesAmount = totalFeesByCurrencyBuckets.fold<double>(
      0, (sum, b) => sum + b.totalAmount);
    final smartInsights = _buildSmartInsights(
      internationalExpenseCount: international,
      domesticExpenseCount: domestic,
      transactionCurrencyCount: txCurrencyMap.length,
      totalBilledAmount: totalBilledAmount,
      totalFeesAmount: totalFeesAmount,
      hasInternationalFees: hasInternationalFees,
    );

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

  List<TripReportInsight> _buildSmartInsights({
    required int internationalExpenseCount,
    required int domesticExpenseCount,
    required int transactionCurrencyCount,
    required double totalBilledAmount,
    required double totalFeesAmount,
    required bool hasInternationalFees,
  }) {
    final insights = <TripReportInsight>[];

    // 1. Dominant behavior first — most spending was abroad.
    if (internationalExpenseCount > domesticExpenseCount &&
        internationalExpenseCount > 0) {
      insights.add(const TripReportInsight(
        type: TripReportInsightType.internationalDominant,
      ));
    }

    // 2. Context second — highlight cross-currency complexity.
    if (transactionCurrencyCount > 1) {
      insights.add(TripReportInsight(
        type: TripReportInsightType.multipleCurrencies,
        percentage: transactionCurrencyCount,
      ));
    }

    // 3. Bonus fee signal last.
    if (hasInternationalFees && totalBilledAmount > 0) {
      final feePct = _toPercentage(totalFeesAmount, totalBilledAmount);
      if (feePct > 0) {
        insights.add(TripReportInsight(
          type: TripReportInsightType.feesPercentage,
          percentage: feePct,
        ));
      }
    }

    // 3. Bonus reassurance last when no fees were charged.
    if (internationalExpenseCount > 0 && !hasInternationalFees) {
      insights.add(const TripReportInsight(
        type: TripReportInsightType.noInternationalFees,
      ));
    }

    return insights.take(3).toList(growable: false);
  }

  int _toPercentage(double value, double total) {
    if (total <= 0) {
      return 0;
    }
    return ((value / total) * 100).round();
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
