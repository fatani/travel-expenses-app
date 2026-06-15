import '../../refunds/domain/expense_refund.dart';
import 'report_bucket.dart';
import 'trip_report_summary.dart';

/// Report data assembled for presentation — calculator output plus display-only
/// refund currency buckets (face-value sums from stored refund rows).
class TripReportDisplay {
  const TripReportDisplay({
    required this.summary,
    required this.refundsByTransactionCurrency,
  });

  final TripReportSummary summary;
  final List<ReportBucket> refundsByTransactionCurrency;

  bool get hasRefundsByTransactionCurrency =>
      refundsByTransactionCurrency.isNotEmpty;
}

/// Sums active refund face-value amounts grouped by transaction currency.
///
/// Display-only aggregation — does not alter [TripReportCalculator] math.
List<ReportBucket> buildRefundsByTransactionCurrency(
  List<ExpenseRefund> refunds,
) {
  final totals = <String, _RefundAccumulator>{};
  for (final refund in refunds) {
    if (refund.isReversed) {
      continue;
    }
    final currency = refund.currencyCode.trim().toUpperCase();
    totals
        .putIfAbsent(currency, () => _RefundAccumulator())
        .add(refund.amount);
  }

  return totals.entries
      .map(
        (entry) => ReportBucket(
          key: entry.key,
          currency: entry.key,
          totalAmount: entry.value.total,
          count: entry.value.count,
        ),
      )
      .toList()
    ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
}

/// Gross transaction-currency total for [currency], or 0 when absent.
double grossTransactionAmountForCurrency(
  TripReportSummary summary,
  String currency,
) {
  final normalized = currency.trim().toUpperCase();
  return summary.totalBilledByCurrency
      .where((bucket) => bucket.currency.trim().toUpperCase() == normalized)
      .fold<double>(0, (sum, bucket) => sum + bucket.totalAmount);
}

/// Refund face-value total for [currency], or 0 when absent.
double refundTransactionAmountForCurrency(
  List<ReportBucket> refundsByTransactionCurrency,
  String currency,
) {
  final normalized = currency.trim().toUpperCase();
  return refundsByTransactionCurrency
      .where((bucket) => bucket.currency.trim().toUpperCase() == normalized)
      .fold<double>(0, (sum, bucket) => sum + bucket.totalAmount);
}

/// Net = gross expenses − refund face values per currency (no conversion).
double netTransactionAmountForCurrency({
  required TripReportSummary summary,
  required List<ReportBucket> refundsByTransactionCurrency,
  required String currency,
}) {
  return grossTransactionAmountForCurrency(summary, currency) -
      refundTransactionAmountForCurrency(refundsByTransactionCurrency, currency);
}

/// Currencies appearing in gross and/or refund transaction buckets.
List<String> reportTransactionCurrencies(TripReportDisplay display) {
  final currencies = <String>{
    ...display.summary.totalBilledByCurrency.map((b) => b.currency),
    ...display.refundsByTransactionCurrency.map((b) => b.currency),
  };
  final ordered = display.summary.totalBilledByCurrency
      .map((b) => b.currency.trim().toUpperCase())
      .toList();
  for (final currency in currencies) {
    if (!ordered.contains(currency)) {
      ordered.add(currency);
    }
  }
  return ordered;
}

class _RefundAccumulator {
  double total = 0;
  int count = 0;

  void add(double amount) {
    total += amount;
    count++;
  }
}
