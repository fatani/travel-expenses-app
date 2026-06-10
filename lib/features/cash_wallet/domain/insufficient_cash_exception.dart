/// Thrown by the FIFO engine when the open lots for a given trip + currency
/// do not hold enough balance to satisfy a requested consumption amount.
class InsufficientCashException implements Exception {
  const InsufficientCashException({
    required this.required,
    required this.available,
    required this.currencyCode,
  });

  /// The amount that was requested.
  final double required;

  /// The total available balance across all open lots.
  final double available;

  /// The currency code (upper-case) for which the shortage occurred.
  final String currencyCode;

  @override
  String toString() => 'InsufficientCashException('
      'required: $required, '
      'available: $available, '
      'currencyCode: $currencyCode)';
}
