import 'remaining_cash_value.dart';
import 'report_bucket.dart';
import 'reporting_money_preview.dart';

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
    this.reportingMoneyPreviews = const [],
    this.grossSpendingHomeAmount,
    this.grossSpendingHomeCurrency,
    this.refundHomeAmount,
    this.netSpendingHomeAmount,
    this.remainingCashValues = const [],
    this.netTripCostHomeAmount,
  });

  final String tripId;
  final String tripName;

  /// Total number of expenses in the trip.
  final int totalExpenseCount;

  /// Number of expenses flagged as international.
  final int internationalExpenseCount;

  /// Number of domestic expenses.
  final int domesticExpenseCount;

  /// Transaction totals grouped by transaction currency.
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

    /// Foundation data for later UI: original amount + optional home equivalent.
    final List<ReportingMoneyPreview> reportingMoneyPreviews;

  /// Sum of convertedHomeAmount for all real expenses that have a home-currency
  /// conversion. Null when no expense has a convertedHomeAmount.
  final double? grossSpendingHomeAmount;

  /// The home currency used for [grossSpendingHomeAmount]. Null when no expense
  /// has a convertedHomeAmount.
  final String? grossSpendingHomeCurrency;

  /// Sum of [homeAmount] for all active (non-reversed) refunds whose
  /// [homeCurrency] matches [grossSpendingHomeCurrency]. Null when no such
  /// refund exists.
  final double? refundHomeAmount;

  /// Net Spending = Gross Spending − Active Refunds.
  ///
  /// Null when [grossSpendingHomeAmount] is null (no home-currency data).
  /// Equals [grossSpendingHomeAmount] when [refundHomeAmount] is null.
  final double? netSpendingHomeAmount;

  /// Cost-basis value of every remaining cash balance, one entry per currency.
  ///
  /// Empty when no balance has a usable effective rate. Each entry satisfies:
  /// `homeAmount = balanceAmount × effectiveRate`.
  final List<RemainingCashValue> remainingCashValues;

  /// Net Trip Cost = [netSpendingHomeAmount] − totalRemainingCashHomeAmount.
  ///
  /// Null when [netSpendingHomeAmount] is null (no home-currency data).
  /// Equals [netSpendingHomeAmount] when [remainingCashValues] is empty or none
  /// match [grossSpendingHomeCurrency].
  final double? netTripCostHomeAmount;

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
