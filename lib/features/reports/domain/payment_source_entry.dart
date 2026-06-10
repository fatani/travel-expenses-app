/// One row in the Payment Source Summary.
///
/// Groups active (non-reversed) expenses by [paymentType] +
/// [transactionCurrency].  Produced by [TripReportCalculator].
class PaymentSourceEntry {
  const PaymentSourceEntry({
    required this.paymentType,
    required this.transactionCurrency,
    required this.totalTransactionAmount,
    this.totalHomeAmount,
    this.homeCurrency,
    required this.count,
  });

  /// Normalised payment method: `'cash'`, `'card'`, or `'other'`.
  final String paymentType;

  /// Transaction (foreign) currency of expenses in this group, e.g. `'JPY'`.
  final String transactionCurrency;

  /// SUM(expense.transactionAmount) for all active expenses in this group.
  final double totalTransactionAmount;

  /// SUM(expense.convertedHomeAmount) for expenses in this group that share a
  /// common [homeCurrency].  Null when home-currency data is absent or mixed.
  final double? totalHomeAmount;

  /// Home currency code shared by qualifying expenses in this group, or null.
  final String? homeCurrency;

  /// Number of active, non-reversed expenses contributing to this entry.
  final int count;
}
