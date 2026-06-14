import '../../expenses/domain/expense.dart';

/// Derives a linked refund home-currency snapshot from stored expense fields.
///
/// Mirrors refund model spec §1.4 using only persisted expense values.
({double? homeAmount, String? homeCurrency}) linkedRefundHomeSnapshot({
  required Expense expense,
  required double refundAmount,
}) {
  if (refundAmount <= 0) {
    return (homeAmount: null, homeCurrency: null);
  }

  final homeCurrency = expense.homeCurrency?.trim().toUpperCase();
  if (homeCurrency == null || homeCurrency.isEmpty) {
    return (homeAmount: null, homeCurrency: null);
  }

  final rate = expense.conversionRate;
  if (rate != null && rate > 0) {
    return (homeAmount: refundAmount * rate, homeCurrency: homeCurrency);
  }

  final convertedHome = expense.convertedHomeAmount;
  final transactionAmount = expense.transactionAmount;
  if (convertedHome != null && convertedHome > 0 && transactionAmount > 0) {
    return (
      homeAmount: (refundAmount / transactionAmount) * convertedHome,
      homeCurrency: homeCurrency,
    );
  }

  return (homeAmount: null, homeCurrency: homeCurrency);
}
