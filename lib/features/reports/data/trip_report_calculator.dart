import '../../cash_wallet/domain/cash_lot.dart';
import '../../expenses/domain/expense.dart';
import '../../refunds/domain/expense_refund.dart';
import '../domain/cash_acquisition_entry.dart';
import '../domain/payment_source_entry.dart';
import '../domain/remaining_cash_value.dart';
import '../../insights/data/insight_engine.dart';
import '../../insights/domain/insight.dart';
import '../domain/report_bucket.dart';
import '../domain/reporting_money_preview.dart';
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
    List<ExpenseRefund> refunds = const [],
    List<CashBalanceRateInput> cashBalanceRates = const [],
    List<RemainingCashValue> lotRemainingValues = const [],
    List<CashLot> activeLots = const [],
  }) {
    if (expenses.isEmpty) {
      final emptyRemainingCash = lotRemainingValues.isNotEmpty
          ? lotRemainingValues
          : _buildRemainingCashValues(cashBalanceRates);
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
        reportingMoneyPreviews: const [],
        grossSpendingHomeAmount: null,
        grossSpendingHomeCurrency: null,
        refundHomeAmount: null,
        netSpendingHomeAmount: null,
        remainingCashValues: emptyRemainingCash,
        netTripCostHomeAmount: null,
        cashAcquisitionSummary: _buildCashAcquisitionSummary(activeLots),
        paymentSourceSummary: const [],
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

    final hasMultipleTransactionCurrencies = txCurrencyMap.length > 1;

    // Top category is suppressed when totals span multiple transaction currencies.
    String? topCategory;
    if (!hasMultipleTransactionCurrencies) {
      double topAmount = -1;
      categoryMap.forEach((cat, currencyAccumulators) {
        final catTotal = currencyAccumulators.values
            .fold<double>(0, (sum, acc) => sum + acc.total);
        if (catTotal > topAmount) {
          topAmount = catTotal;
          topCategory = cat;
        }
      });
    }

    final byCategoryBuckets = _toNestedBuckets(categoryMap);
    final byTransactionCurrencyBuckets =
        _toBuckets(txCurrencyMap, keyFn: (k) => k);
    final byPaymentNetworkBuckets = _toNestedBuckets(networkMap);
    final byPaymentChannelBuckets = _toNestedBuckets(channelMap);
    final totalBilledByCurrencyBuckets =
        _toBuckets(billedByCurrency, keyFn: (k) => k);
    final totalFeesByCurrencyBuckets =
        _toBuckets(feesByCurrency, keyFn: (k) => k);
    String? topPaymentNetwork;
    String? topPaymentChannel;
    if (!hasMultipleTransactionCurrencies) {
      topPaymentNetwork = _topNestedKey(networkMap);
      topPaymentChannel = _topNestedKey(channelMap);
    }
    final smartInsights = (expenses.length < 5
            ? const <Insight>[]
            : _insightEngine.build(
                expenses,
                maxInsights: 1,
                tripNamesById: {tripId: tripName},
              ))
        .map(_toTripInsight)
        .toList(growable: false);
    final reportingMoneyPreviews = expenses
        .map(
          (expense) => ReportingMoneyPreview(
            originalAmount: expense.originalAmount ?? expense.transactionAmount,
            originalCurrency: expense.originalCurrency ?? expense.transactionCurrency,
            convertedHomeAmount: expense.convertedHomeAmount,
            homeCurrency: expense.homeCurrency,
          ),
        )
        .toList(growable: false);

    // --- gross spending in home currency ------------------------------------
    // Only expenses whose homeCurrency matches the first non-null homeCurrency
    // are summed. Expenses with a different homeCurrency are skipped to avoid
    // silently merging amounts denominated in different currencies.
    double grossTotal = 0;
    String? grossCurrency;
    for (final e in expenses) {
      if (e.convertedHomeAmount == null) continue;
      final currency = e.homeCurrency;
      if (currency == null) continue;
      grossCurrency ??= currency;
      if (currency != grossCurrency) continue;
      grossTotal += e.convertedHomeAmount!;
    }
    final double? grossSpendingHomeAmount =
        grossCurrency != null ? grossTotal : null;

    // --- net spending in home currency --------------------------------------
    // Only active (non-reversed) refunds whose homeCurrency matches the gross
    // currency are included. Transaction-currency buckets are never touched.
    double refundTotal = 0;
    bool hasValidRefund = false;
    if (grossCurrency != null) {
      for (final r in refunds) {
        if (r.isReversed) continue;
        if (r.homeAmount == null) continue;
        if (r.homeCurrency != grossCurrency) continue;
        refundTotal += r.homeAmount!;
        hasValidRefund = true;
      }
    }
    final double? refundHomeAmount = hasValidRefund ? refundTotal : null;
    final double? netSpendingHomeAmount = grossSpendingHomeAmount != null
        ? grossSpendingHomeAmount - (refundHomeAmount ?? 0)
        : null;

    // --- remaining cash values -------------------------------------------------
    // If lot-based values are provided (new FIFO path) use them;
    // otherwise fall back to the weighted-average path (backward compat).
    final remainingCashValues = lotRemainingValues.isNotEmpty
        ? lotRemainingValues
        : _buildRemainingCashValues(cashBalanceRates);

    // --- net trip cost ---------------------------------------------------------
    // Net Trip Cost = Net Spending − Total Remaining Cash (home-currency value).
    // Only remaining cash entries whose homeCurrency matches grossCurrency count.
    double? netTripCostHomeAmount;
    if (netSpendingHomeAmount != null) {
      final totalRemainingCashHome = remainingCashValues
          .where((v) => grossCurrency != null && v.homeCurrency == grossCurrency)
          .fold<double>(0, (sum, v) => sum + v.homeAmount);
      netTripCostHomeAmount = netSpendingHomeAmount - totalRemainingCashHome;
    }

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
      reportingMoneyPreviews: reportingMoneyPreviews,
      grossSpendingHomeAmount: grossSpendingHomeAmount,
      grossSpendingHomeCurrency: grossCurrency,
      refundHomeAmount: refundHomeAmount,
      netSpendingHomeAmount: netSpendingHomeAmount,
      remainingCashValues: remainingCashValues,
      netTripCostHomeAmount: netTripCostHomeAmount,
      cashAcquisitionSummary: _buildCashAcquisitionSummary(activeLots),
      paymentSourceSummary: _buildPaymentSourceSummary(expenses),
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
    }
  }

  // ---------------------------------------------------------------------------
  // Cash Acquisition Summary
  // ---------------------------------------------------------------------------

  /// Builds one [CashAcquisitionEntry] per (sourceType, originalCurrency) pair
  /// from [lots].
  ///
  /// Only active (non-reversed) lots should be passed — the caller is
  /// responsible for pre-filtering; this method does not re-check [CashLot.isReversed].
  ///
  /// [totalHomeAmount] and [homeCurrency] are included only when every lot in
  /// the group shares the same non-null [homeCurrencyCode].
  static List<CashAcquisitionEntry> _buildCashAcquisitionSummary(
    List<CashLot> lots,
  ) {
    if (lots.isEmpty) return const [];

    // key = 'sourceType|CURRENCY'
    final groups = <String, _LotAccumulator>{};
    for (final lot in lots) {
      final key = '${lot.sourceType}|${lot.currencyCode}';
      groups.putIfAbsent(key, () => _LotAccumulator(lot.sourceType, lot.currencyCode));
      groups[key]!.add(lot);
    }

    return groups.values.map((acc) => acc.toEntry()).toList()
      ..sort((a, b) {
        final sourceOrder = const [
          'initial_cash',
          'atm_withdrawal',
          'exchange_in',
          'cash_refund',
          'manual_adjustment',
        ].indexOf(a.sourceType).compareTo(
              const [
                'initial_cash',
                'atm_withdrawal',
                'exchange_in',
                'cash_refund',
                'manual_adjustment',
              ].indexOf(b.sourceType),
            );
        if (sourceOrder != 0) return sourceOrder;
        return a.originalCurrency.compareTo(b.originalCurrency);
      });
  }

  // ---------------------------------------------------------------------------
  // Payment Source Summary
  // ---------------------------------------------------------------------------

  /// Normalises an expense [paymentMethod] to `'cash'`, `'card'`, or `'other'`.
  static String _normalisePaymentType(String paymentMethod) {
    final lower = paymentMethod.trim().toLowerCase();
    if (lower == 'cash') return 'cash';
    if (lower == 'card' ||
        lower == 'credit card' ||
        lower == 'debit card') {
      return 'card';
    }
    return 'other';
  }

  /// Builds one [PaymentSourceEntry] per (paymentType, transactionCurrency)
  /// from active (non-reversed) [expenses].
  static List<PaymentSourceEntry> _buildPaymentSourceSummary(
    List<Expense> expenses,
  ) {
    // key = 'paymentType|CURRENCY'
    final groups = <String, _ExpenseAccumulator>{};
    for (final e in expenses) {
      if (e.isReversed) continue;
      final type = _normalisePaymentType(e.paymentMethod);
      final currency = e.transactionCurrency.toUpperCase();
      final key = '$type|$currency';
      groups
          .putIfAbsent(key, () => _ExpenseAccumulator(type, currency))
          .add(e);
    }

    return groups.values.map((acc) => acc.toEntry()).toList()
      ..sort((a, b) {
        final typeOrder = const ['cash', 'card', 'other']
            .indexOf(a.paymentType)
            .compareTo(const ['cash', 'card', 'other'].indexOf(b.paymentType));
        if (typeOrder != 0) return typeOrder;
        return a.transactionCurrency.compareTo(b.transactionCurrency);
      });
  }

  /// Filters [inputs] and produces a [RemainingCashValue] for each entry that
  /// has a positive balance, a non-null effective rate, and a non-null home
  /// currency.
  static List<RemainingCashValue> _buildRemainingCashValues(
    List<CashBalanceRateInput> inputs,
  ) {
    final result = <RemainingCashValue>[];
    for (final input in inputs) {
      final rate = input.effectiveRate;
      final homeCurrency = input.homeCurrency;
      if (rate == null) continue;
      if (homeCurrency == null) continue;
      if (input.balance.balanceAmount <= 0) continue;
      result.add(RemainingCashValue(
        currencyCode: input.balance.currencyCode,
        balanceAmount: input.balance.balanceAmount,
        effectiveRate: rate,
        homeAmount: input.balance.balanceAmount * rate,
        homeCurrency: homeCurrency,
      ));
    }
    return result;
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

// ---------------------------------------------------------------------------
// Lot accumulator (Cash Acquisition Summary)
// ---------------------------------------------------------------------------

class _LotAccumulator {
  _LotAccumulator(this.sourceType, this.currency);

  final String sourceType;
  final String currency;

  double totalOriginal = 0;
  double totalHome = 0;
  bool hasAnyHome = false;
  bool homeCurrencyConsistent = true;
  String? homeCurrencyCode;
  int count = 0;

  void add(CashLot lot) {
    totalOriginal += lot.originalAmount;
    count++;
    final homeAmt = lot.homeCurrencyAmount;
    final homeCode = lot.homeCurrencyCode;
    if (homeAmt != null && homeCode != null) {
      totalHome += homeAmt;
      hasAnyHome = true;
      if (homeCurrencyCode == null) {
        homeCurrencyCode = homeCode;
      } else if (homeCurrencyCode != homeCode) {
        homeCurrencyConsistent = false;
      }
    } else {
      // At least one lot has no home data → consistency broken
      homeCurrencyConsistent = false;
    }
  }

  CashAcquisitionEntry toEntry() {
    final canShowHome = hasAnyHome && homeCurrencyConsistent;
    return CashAcquisitionEntry(
      sourceType: sourceType,
      originalCurrency: currency,
      totalOriginalAmount: totalOriginal,
      totalHomeAmount: canShowHome ? totalHome : null,
      homeCurrency: canShowHome ? homeCurrencyCode : null,
      count: count,
    );
  }
}

// ---------------------------------------------------------------------------
// Expense accumulator (Payment Source Summary)
// ---------------------------------------------------------------------------

class _ExpenseAccumulator {
  _ExpenseAccumulator(this.paymentType, this.currency);

  final String paymentType;
  final String currency;

  double totalTransaction = 0;
  double totalHome = 0;
  bool hasAnyHome = false;
  bool homeCurrencyConsistent = true;
  String? homeCurrencyCode;
  int count = 0;

  void add(Expense e) {
    totalTransaction += e.transactionAmount;
    count++;
    final homeAmt = e.convertedHomeAmount;
    final homeCode = e.homeCurrency;
    if (homeAmt != null && homeCode != null) {
      totalHome += homeAmt;
      hasAnyHome = true;
      if (homeCurrencyCode == null) {
        homeCurrencyCode = homeCode;
      } else if (homeCurrencyCode != homeCode) {
        homeCurrencyConsistent = false;
      }
    }
    // expenses without home data simply don't contribute to home total
  }

  PaymentSourceEntry toEntry() {
    final canShowHome = hasAnyHome && homeCurrencyConsistent;
    return PaymentSourceEntry(
      paymentType: paymentType,
      transactionCurrency: currency,
      totalTransactionAmount: totalTransaction,
      totalHomeAmount: canShowHome ? totalHome : null,
      homeCurrency: canShowHome ? homeCurrencyCode : null,
      count: count,
    );
  }
}
