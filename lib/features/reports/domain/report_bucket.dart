/// A named bucket holding a total amount for a single currency.
/// Used for grouped summaries (by category, network, channel, etc.).
class ReportBucket {
  const ReportBucket({
    required this.key,
    required this.currency,
    required this.totalAmount,
    required this.count,
  });

  /// The grouping key (e.g. category name, currency code, network name).
  final String key;

  /// The currency of [totalAmount].
  final String currency;

  /// Sum of all expense amounts in this bucket for [currency].
  final double totalAmount;

  /// Number of expenses contributing to this bucket.
  final int count;

  @override
  String toString() =>
      'ReportBucket(key: $key, currency: $currency, total: $totalAmount, count: $count)';
}
