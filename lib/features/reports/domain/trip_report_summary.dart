import 'report_bucket.dart';

enum TripReportInsightType {
  multipleCurrencies,
  internationalDominant,
  feesPercentage,
  noInternationalFees,
  spike,
  categoryDrift,
  // kept for backward compat; not emitted by calculator anymore
  dominantCurrency,
  topCategory,
  dominantPaymentChannel,
  dominantTripTypeShare,
}

class TripReportInsight {
  const TripReportInsight({
    required this.type,
    this.subject,
    this.percentage,
    this.isInternational,
  });

  final TripReportInsightType type;
  final String? subject;
  final int? percentage;
  final bool? isInternational;
}

/// Immutable summary of all expenses for a single trip.
class TripReportSummary {
  const TripReportSummary({
    required this.tripId,
    required this.tripName,
    required this.totalExpenseCount,
    required this.internationalExpenseCount,
    required this.domesticExpenseCount,
    required this.totalBilledByCurrency,
    required this.totalFeesByCurrency,
    required this.topCategory,
    required this.topPaymentNetwork,
    required this.topPaymentChannel,
    required this.byCategory,
    required this.byTransactionCurrency,
    required this.byPaymentNetwork,
    required this.byPaymentChannel,
    required this.smartInsights,
  });

  final String tripId;
  final String tripName;

  /// Total number of expenses in the trip.
  final int totalExpenseCount;

  /// Number of expenses flagged as international.
  final int internationalExpenseCount;

  /// Number of domestic expenses.
  final int domesticExpenseCount;

  /// Total billed (SAR-equivalent) grouped by billing currency.
  /// Currencies are intentionally kept separate — never merged.
  final List<ReportBucket> totalBilledByCurrency;

  /// Total fees grouped by fee currency.
  final List<ReportBucket> totalFeesByCurrency;

  /// The category with the highest total spend (null if no categories set).
  final String? topCategory;

  /// The payment network with the highest total spend.
  final String? topPaymentNetwork;

  /// The payment channel with the highest total spend.
  final String? topPaymentChannel;

  /// Spending grouped by expense category, then by currency.
  final List<ReportBucket> byCategory;

  /// Spending grouped by transaction currency.
  final List<ReportBucket> byTransactionCurrency;

  /// Spending grouped by payment network (Visa, Mastercard, Mada, etc.).
  final List<ReportBucket> byPaymentNetwork;

  /// Spending grouped by payment channel (POS, Online, etc.).
  final List<ReportBucket> byPaymentChannel;

    /// Lightweight insights that help the user scan the report quickly.
    final List<TripReportInsight> smartInsights;

  /// Convenience: true when the trip has at least one international expense.
  bool get hasInternational => internationalExpenseCount > 0;

  /// Convenience: true when fees were recorded.
  bool get hasFees => totalFeesByCurrency.isNotEmpty;

    ReportBucket? get topBilledBucket =>
      totalBilledByCurrency.isEmpty ? null : totalBilledByCurrency.first;

    ReportBucket? get topFeesBucket =>
      totalFeesByCurrency.isEmpty ? null : totalFeesByCurrency.first;

    ReportBucket? get topTransactionCurrencyBucket =>
      byTransactionCurrency.isEmpty ? null : byTransactionCurrency.first;
}
